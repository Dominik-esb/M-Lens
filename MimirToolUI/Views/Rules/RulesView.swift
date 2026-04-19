import SwiftUI
import UniformTypeIdentifiers

struct RulesView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: RulesViewModel
    @State private var showEditor = false
    @State private var editingYAML = ""
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: (namespace: String, group: String, ruleName: String)? = nil
    @State private var showFilePicker = false
    @State private var showGuidedCreator = false
    @State private var selectedRule: Rule?
    @State private var isDragTargeted = false
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: RulesViewModel(
            runner: MimirtoolRunner.fromAppStorage(),
            environment: environment
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Rules").font(.system(size: 20, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                RefreshButton(isLoading: vm.isLoading) { Task { await vm.load() } }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(t.textFaint).font(.system(size: 12))
                    TextField("Search…", text: $vm.searchText)
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(t.searchBg)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(t.borderSub, lineWidth: 1))
                .frame(width: 200)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

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

                Button { showGuidedCreator = true } label: {
                    Label("Create…", systemImage: "wand.and.stars").font(.system(size: 12))
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }
                    .padding(.horizontal, 20).padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

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
                .background(t.surfaceAlt)
                .overlay(Rectangle().frame(height: 1).foregroundColor(t.headerLine), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filtered) { ns in
                            ForEach(ns.groups) { group in
                                ForEach(group.rules) { rule in
                                    ruleRow(rule: rule, ns: ns, group: group)
                                }
                            }
                        }
                        if vm.isLoading && vm.namespaces.isEmpty {
                            ProgressView().padding(40)
                        }
                        if !vm.isLoading && vm.namespaces.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text").font(.system(size: 28))
                                    .foregroundStyle(.tertiary)
                                Text("No rules found.")
                                    .foregroundStyle(.secondary).font(.system(size: 13))
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
                            RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#7ab3f0").opacity(0.10))
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc").font(.system(size: 28))
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
                        Task { @MainActor in await vm.push(yamlContent: yaml) }
                    }
                }
                return true
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(t.bg)
        .overlay(
            Group {
                if let msg = vm.activityMessage {
                    VStack {
                        Spacer()
                        ActivityToastView(message: msg)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.3), value: vm.activityMessage)
        )
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
        .sheet(isPresented: $showGuidedCreator) {
            GuidedRuleSheet { yaml in
                Task { await vm.push(yamlContent: yaml) }
            }
        }
        .alert("Delete Rule?", isPresented: $showDeleteConfirm, presenting: deleteTarget) { target in
            Button("Delete", role: .destructive) {
                Task { await vm.deleteRule(namespace: target.namespace, group: target.group, ruleName: target.ruleName) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("\"\(target.ruleName)\" will be removed from group \"\(target.group)\". Other rules in the group are not affected.")
        }
    }

    @ViewBuilder
    private func ruleRow(rule: Rule, ns: RuleNamespace, group: RuleGroup) -> some View {
        RuleRowView(
            rule: rule,
            onTap: { selectedRule = rule },
            onEdit: {
                Task {
                    editingYAML = (try? await vm.fetchRuleGroupYAML(namespace: rule.namespace, group: rule.group)) ?? ""
                    showEditor = true
                }
            },
            onDelete: {
                deleteTarget = (namespace: ns.name, group: group.name, ruleName: rule.ruleName)
                showDeleteConfirm = true
            }
        )
    }
}

// MARK: - Rule Row

private struct RuleRowView: View {
    let rule: Rule
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                TagView(text: rule.namespace, style: .namespace)
                    .frame(width: 120, alignment: .leading)
                Text(rule.group)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(width: 160, alignment: .leading).lineLimit(1)
                Text(rule.ruleName)
                    .font(.system(size: 13)).foregroundStyle(.primary)
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
            .background(isHovered ? t.rowHover : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .overlay(Rectangle().frame(height: 1).foregroundColor(t.rowLine), alignment: .bottom)
    }

    @ViewBuilder
    private func iconBtn(systemImage: String, danger: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 11))
                .frame(width: 26, height: 26)
                .foregroundColor(danger ? Color(hex: "#f87171") : t.iconColor)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(
                    danger ? t.btnDanBorder : t.iconBtnBorder, lineWidth: 1))
                .cornerRadius(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onTapGesture { action() }
    }
}

// MARK: - Rule Detail Sheet

private struct RuleDetailSheet: View {
    let rule: Rule
    let runner: MimirtoolRunning
    let environment: MimirEnvironment
    let onEdit: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }
    @State private var yaml: String = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rule.ruleName)
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
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
            .background(t.surfaceAlt)
            .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)

            HStack(spacing: 24) {
                metaItem("GROUP", value: rule.group)
                metaItem("NAMESPACE", value: rule.namespace)
                metaItem("TYPE", value: rule.type.rawValue.capitalized)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(t.surface)
            .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("YAML").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary).tracking(0.7)
                    Spacer()
                    if isLoading { ProgressView().scaleEffect(0.6) }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(t.surfaceAlt)
                .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)

                ScrollView {
                    Text(yaml.isEmpty && !isLoading ? "Could not load YAML." : yaml)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(t.textSub)
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
        .background(t.surface)
        .task {
            yaml = (try? await runner.run(["rules", "get", rule.namespace, rule.group], environment: environment)) ?? ""
            isLoading = false
        }
    }

    private func metaItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            Text(value).font(.system(size: 12)).foregroundColor(t.textSub)
        }
    }
}

// MARK: - Shared Button Styles

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var cs
    func makeBody(configuration: Configuration) -> some View {
        let t = Theme(cs)
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(t.btnSecBg)
            .foregroundColor(t.btnSecFg)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.btnSecBorder, lineWidth: 1))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var cs
    func makeBody(configuration: Configuration) -> some View {
        let t = Theme(cs)
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(t.btnAccBg)
            .foregroundColor(t.btnAccFg)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.btnAccBorder, lineWidth: 1))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var danger = false
    @Environment(\.colorScheme) var cs
    func makeBody(configuration: Configuration) -> some View {
        let t = Theme(cs)
        configuration.label
            .frame(width: 26, height: 26)
            .background(configuration.isPressed ? (danger ? t.btnDanBg : t.btnSecBg) : Color.clear)
            .foregroundColor(danger ? Color(hex: "#f87171") : t.iconColor)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                danger ? t.iconBtnDanBorder : t.iconBtnBorder, lineWidth: 1))
            .cornerRadius(6)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Shared view extensions

extension View {
    func tableHeader() -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.7)
    }
}

extension UTType {
    static var yaml: UTType { UTType(filenameExtension: "yaml") ?? .plainText }
}
