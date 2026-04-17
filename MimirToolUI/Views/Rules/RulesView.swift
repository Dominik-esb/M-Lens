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
    @State private var selectedRule: Rule?

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
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color(hex: "#666666"))
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(vm.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isLoading)
                }.buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "#555555")).font(.system(size: 12))
                    TextField("Search…", text: $vm.searchText)
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(Color(hex: "#c8c8c8"))
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
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

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }
                    .padding(.horizontal, 20).padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Table
            VStack(spacing: 0) {
                HStack {
                    Text("NAMESPACE").tableHeader().frame(width: 120, alignment: .leading)
                    Text("GROUP").tableHeader().frame(width: 160, alignment: .leading)
                    Text("RULE NAME").tableHeader()
                    Spacer()
                    Text("TYPE").tableHeader().frame(width: 90, alignment: .leading)
                    Text("ACTIONS").tableHeader().frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(hex: "#1a1a1a"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filtered) { ns in
                            ForEach(ns.groups) { group in
                                ForEach(group.rules) { rule in
                                    RuleRowView(
                                        rule: rule,
                                        onTap: { selectedRule = rule },
                                        onEdit: {
                                            Task {
                                                editingYAML = (try? await vm.fetchRuleGroupYAML(namespace: rule.namespace, group: rule.group)) ?? ""
                                                showEditor = true
                                            }
                                        },
                                        onDelete: { deleteTarget = (ns.name, group.name); showDeleteConfirm = true }
                                    )
                                }
                            }
                        }
                        if vm.isLoading && vm.namespaces.isEmpty {
                            ProgressView().padding(40)
                        }
                        if !vm.isLoading && vm.namespaces.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text").font(.system(size: 28))
                                    .foregroundColor(Color(hex: "#3a3a3a"))
                                Text("No rules found.")
                                    .foregroundColor(Color(hex: "#444444")).font(.system(size: 13))
                            }
                            .padding(40)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: vm.namespaces.count)
                }

                StatusBarView(
                    environment: environment,
                    statusText: "\(vm.namespaces.flatMap(\.groups).flatMap(\.rules).count) rules · \(vm.namespaces.count) namespaces"
                )
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
        .task { await vm.load() }
        .sheet(item: $selectedRule) { rule in
            RuleDetailSheet(rule: rule, runner: MimirtoolRunner.fromAppStorage(), environment: environment) {
                Task {
                    editingYAML = (try? await vm.fetchRuleGroupYAML(namespace: rule.namespace, group: rule.group)) ?? ""
                    showEditor = true
                }
            }
        }
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

// MARK: - Rule Row

private struct RuleRowView: View {
    let rule: Rule
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                TagView(text: rule.namespace, style: .namespace)
                    .frame(width: 120, alignment: .leading)
                Text(rule.group)
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#999999"))
                    .frame(width: 160, alignment: .leading).lineLimit(1)
                Text(rule.ruleName)
                    .font(.system(size: 13)).foregroundColor(Color(hex: "#d0d0d0"))
                    .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                TagView(text: rule.type.rawValue, style: rule.type == .alerting ? .alerting : .recording)
                    .frame(width: 90, alignment: .leading)
                HStack(spacing: 4) {
                    iconBtn(systemImage: "pencil", danger: false) { onEdit() }
                    iconBtn(systemImage: "xmark", danger: true) { onDelete() }
                }
                .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isHovered ? Color(hex: "#232323") : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#242424")), alignment: .bottom)
    }

    @ViewBuilder
    private func iconBtn(systemImage: String, danger: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 11))
                .frame(width: 26, height: 26)
                .foregroundColor(danger ? Color(hex: "#f87171") : Color(hex: "#666666"))
                .background(Color(hex: danger ? "#2e1515" : "#2a2a2a").opacity(0))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: danger ? "#4a2020" : "#333333"), lineWidth: 1))
                .cornerRadius(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onTapGesture { action() }  // prevent row tap from firing
    }
}

// MARK: - Rule Detail Sheet

private struct RuleDetailSheet: View {
    let rule: Rule
    let runner: MimirtoolRunning
    let environment: MimirEnvironment
    let onEdit: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var yaml: String = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rule.ruleName)
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white).lineLimit(2)
                    HStack(spacing: 6) {
                        TagView(text: rule.namespace, style: .namespace)
                        TagView(text: rule.type.rawValue, style: rule.type == .alerting ? .alerting : .recording)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button("Edit") { onEdit(); dismiss() }.buttonStyle(SecondaryButtonStyle())
                    Button("Close") { dismiss() }.buttonStyle(AccentButtonStyle())
                }
            }
            .padding(20)
            .background(Color(hex: "#1a1a1a"))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#272727")), alignment: .bottom)

            // Metadata row
            HStack(spacing: 24) {
                metaItem("GROUP", value: rule.group)
                metaItem("NAMESPACE", value: rule.namespace)
                metaItem("TYPE", value: rule.type.rawValue.capitalized)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color(hex: "#1c1c1c"))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#272727")), alignment: .bottom)

            // YAML section
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("YAML").font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "#555555")).tracking(0.7)
                    Spacer()
                    if isLoading {
                        ProgressView().scaleEffect(0.6)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#1a1a1a"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#272727")), alignment: .bottom)

                ScrollView {
                    Text(yaml.isEmpty && !isLoading ? "Could not load YAML." : yaml)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "#c8c8c8"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .textSelection(.enabled)
                        .opacity(isLoading ? 0.3 : 1)
                        .animation(.easeIn(duration: 0.2), value: isLoading)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 620, height: 500)
        .background(Color(hex: "#1e1e1e"))
        .task {
            yaml = (try? await runner.run(["rules", "get", rule.namespace, rule.group], environment: environment)) ?? ""
            isLoading = false
        }
    }

    private func metaItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(Color(hex: "#555555")).tracking(0.5)
            Text(value).font(.system(size: 12)).foregroundColor(Color(hex: "#c8c8c8"))
        }
    }
}

// MARK: - Shared Button Styles

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color(hex: "#2e2e2e"))
            .foregroundColor(Color(hex: "#bbbbbb"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#3a3a3a"), lineWidth: 1))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
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
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
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
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Shared view extensions

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

