import SwiftUI
import UniformTypeIdentifiers

struct RulesView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: RulesViewModel
    @State private var showEditor = false
    @State private var editingYAML = ""
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: (namespace: String, group: String?)? = nil
    @State private var showFilePicker = false

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: RulesViewModel(
            runner: MimirtoolRunner.fromAppStorage(),
            environment: environment
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text("Rules").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Color(hex: "#666666"))
                }.buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "#555555"))
                    TextField("Search…", text: $vm.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#c8c8c8"))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(Color(hex: "#1e1e1e"))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#333333"), lineWidth: 1))
                .frame(width: 200)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            // Action bar
            HStack(spacing: 8) {
                Button { showFilePicker = true } label: {
                    Label("Upload YAML", systemImage: "arrow.up").font(.system(size: 12))
                }
                .buttonStyle(SecondaryButtonStyle())
                .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.yaml, UTType(filenameExtension: "yml")!]) { result in
                    if case .success(let url) = result {
                        let yaml = (try? String(contentsOf: url)) ?? ""
                        Task { await vm.push(yamlContent: yaml) }
                    }
                }

                Button {
                    editingYAML = "groups:\n  - name: new-group\n    rules: []\n"
                    showEditor = true
                } label: {
                    Label("New Rule", systemImage: "plus").font(.system(size: 12))
                }
                .buttonStyle(AccentButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            // Error banner
            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }.padding(.horizontal, 20)
            }

            // Table card
            VStack(spacing: 0) {
                HStack {
                    Text("NAMESPACE").tableHeader(); Spacer()
                    Text("GROUP").tableHeader().frame(width: 160, alignment: .leading)
                    Text("RULE NAME").tableHeader().frame(width: 220, alignment: .leading)
                    Text("TYPE").tableHeader().frame(width: 90, alignment: .leading)
                    Text("ACTIONS").tableHeader().frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(hex: "#1e1e1e"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filtered) { ns in
                            ForEach(ns.groups) { group in
                                ForEach(group.rules) { rule in
                                    RuleRowView(rule: rule,
                                        onEdit: { editingYAML = rule.yaml; showEditor = true },
                                        onDelete: { deleteTarget = (ns.name, group.name); showDeleteConfirm = true }
                                    )
                                }
                            }
                        }
                        if vm.isLoading {
                            ProgressView().padding(32)
                        }
                        if !vm.isLoading && vm.namespaces.isEmpty {
                            Text("No rules found. Load rules from your Mimir environment.")
                                .foregroundColor(Color(hex: "#444444")).padding(32)
                        }
                    }
                }

                StatusBarView(
                    environment: environment,
                    statusText: "\(vm.namespaces.flatMap(\.groups).flatMap(\.rules).count) rules · \(vm.namespaces.count) namespaces"
                )
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
        .task { await vm.load() }
        .sheet(isPresented: $showEditor) {
            RuleEditorSheet(yaml: $editingYAML) { yaml in
                Task { await vm.push(yamlContent: yaml) }
            }
        }
        .alert("Delete Rule?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let t = deleteTarget {
                    Task {
                        if let group = t.group {
                            await vm.deleteGroup(namespace: t.namespace, group: group)
                        } else {
                            await vm.deleteNamespace(t.namespace)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct RuleRowView: View {
    let rule: Rule
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TagView(text: rule.namespace, style: .namespace)
            Spacer()
            Text(rule.group)
                .font(.system(size: 13)).foregroundColor(Color(hex: "#c8c8c8"))
                .frame(width: 160, alignment: .leading)
            Text(rule.ruleName)
                .font(.system(size: 13)).foregroundColor(Color(hex: "#c8c8c8"))
                .frame(width: 220, alignment: .leading).lineLimit(1)
            TagView(text: rule.type.rawValue, style: rule.type == .alerting ? .alerting : .recording)
                .frame(width: 90, alignment: .leading)
            HStack(spacing: 5) {
                Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(IconButtonStyle())
                Button(action: onDelete) { Image(systemName: "xmark") }.buttonStyle(IconButtonStyle(danger: true))
            }.frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }
}

// MARK: - Shared Button Styles (used across multiple views)

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color(hex: "#2e2e2e"))
            .foregroundColor(Color(hex: "#bbbbbb"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#3a3a3a"), lineWidth: 1))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color(hex: "#1e3a6e"))
            .foregroundColor(Color(hex: "#7ab3f0"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#2a4d8a"), lineWidth: 1))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct IconButtonStyle: ButtonStyle {
    var danger = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 26, height: 26)
            .background(configuration.isPressed ? (danger ? Color(hex: "#2e1515") : Color(hex: "#2a2a2a")) : Color.clear)
            .foregroundColor(danger ? Color(hex: "#f87171") : Color(hex: "#666666"))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(danger ? Color(hex: "#4a2020") : Color(hex: "#333333"), lineWidth: 1))
            .cornerRadius(6)
    }
}

extension View {
    func tableHeader() -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: "#555555"))
            .textCase(.uppercase)
            .tracking(0.7)
    }
}

extension UTType {
    static var yaml: UTType { UTType(filenameExtension: "yaml") ?? .plainText }
}
