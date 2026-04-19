import SwiftUI
import UniformTypeIdentifiers

struct AlertmanagerView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: AlertmanagerViewModel
    @State private var showDeleteConfirm = false
    @State private var showFilePicker = false
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    @State private var diagnostics: [YAMLDiagnostic] = []
    @State private var isChecking = false
    @State private var lintTask: Task<Void, Never>?
    @State private var isDragTargeted = false

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: AlertmanagerViewModel(
            runner: MimirtoolRunner.fromAppStorage(),
            environment: environment
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Page header
            HStack(spacing: 10) {
                Text("Alertmanager").font(.system(size: 20, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                RefreshButton(isLoading: vm.isLoading) { Task { await vm.load() } }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            // Action bar
            HStack(spacing: 8) {
                Button { showFilePicker = true } label: {
                    Label("Upload Config", systemImage: "arrow.up").font(.system(size: 12))
                }
                .buttonStyle(SecondaryButtonStyle())
                .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.yaml]) { result in
                    if case .success(let url) = result {
                        vm.configYAML = (try? String(contentsOf: url)) ?? ""
                        vm.hasUnsavedChanges = true
                    }
                }

                Button { Task { await vm.push() } } label: {
                    Label("Push to Mimir", systemImage: "arrow.up.circle").font(.system(size: 12))
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(!diagnostics.isEmpty)

                Spacer()

                Button { showDeleteConfirm = true } label: {
                    Label("Delete Config", systemImage: "trash").font(.system(size: 12))
                }.buttonStyle(DangerButtonStyle())
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }

            HStack(spacing: 12) {
                // Editor card
                VStack(spacing: 0) {
                    // File title bar
                    HStack {
                        Text("alertmanager.yaml")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        if vm.hasUnsavedChanges {
                            Text("Unsaved changes")
                                .font(.system(size: 11)).foregroundColor(Color(hex: "#fbbf24"))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(t.surfaceAlt)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(t.headerLine), alignment: .bottom)

                    // Lint status strip
                    LintStatusView(diagnostics: diagnostics, isChecking: isChecking)

                    YAMLEditorView(text: $vm.configYAML, hasChanges: $vm.hasUnsavedChanges,
                                   diagnostics: diagnostics)

                    StatusBarView(environment: environment,
                                  statusText: "\(vm.configYAML.components(separatedBy: "\n").count) lines")
                }
                .background(t.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isDragTargeted ? Color(hex: "#7ab3f0") : t.border,
                                lineWidth: isDragTargeted ? 2 : 1)
                )
                .overlay(
                    Group {
                        if isDragTargeted {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "#7ab3f0").opacity(0.10))
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.down.doc")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color(hex: "#7ab3f0"))
                                    Text("Drop YAML to upload")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "#7ab3f0"))
                                }
                            }
                        }
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .onDrop(of: [UTType.fileURL], isTargeted: $isDragTargeted) { providers in
                    for provider in providers {
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                            guard let data,
                                  let urlString = String(data: data, encoding: .utf8),
                                  let url = URL(string: urlString) else { return }
                            let ext = url.pathExtension.lowercased()
                            guard ext == "yaml" || ext == "yml" else { return }
                            guard let yaml = try? String(contentsOf: url) else { return }
                            Task { @MainActor in
                                vm.configYAML = yaml
                                vm.hasUnsavedChanges = true
                            }
                        }
                    }
                    return true
                }

                ConfigSummaryView(yaml: vm.configYAML)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(t.bg)
        .task { await vm.load() }
        .task { await runLint() }
        .onChange(of: vm.configYAML) { _ in scheduleLint() }
        .alert("Delete Alertmanager Config?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await vm.delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the alertmanager configuration for this environment.")
        }
    }

    private func scheduleLint() {
        lintTask?.cancel()
        lintTask = Task {
            isChecking = true
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await runLint()
        }
    }

    private func runLint() async {
        isChecking = true
        diagnostics = await YAMLLinter.lint(vm.configYAML)
        isChecking = false
    }
}

struct DangerButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var cs
    func makeBody(configuration: Configuration) -> some View {
        let t = Theme(cs)
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(t.btnDanBg)
            .foregroundColor(t.btnDanFg)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.btnDanBorder, lineWidth: 1))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
