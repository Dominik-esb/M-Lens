import SwiftUI

struct GuidedRuleSheet: View {
    let onPush: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    enum SheetMode { case guided, yaml }
    @State private var mode: SheetMode = .guided

    enum RuleKind { case alerting, recording }
    @State private var ruleKind: RuleKind = .alerting

    @State private var namespace: String = ""
    @State private var groupName: String = ""
    @State private var ruleName: String = ""
    @State private var expr: String = ""
    @State private var forDuration: String = ""
    @State private var severity: String = "warning"
    @State private var summary: String = ""
    @State private var ruleDescription: String = ""
    @State private var rawYAML: String = ""

    private var guidedRequiredFilled: Bool {
        !namespace.isEmpty && !groupName.isEmpty && !ruleName.isEmpty && !expr.isEmpty
    }

    private var canPush: Bool {
        mode == .guided ? guidedRequiredFilled : !rawYAML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func generateYAML() -> String {
        var yaml = "groups:\n  - name: \(groupName)\n    rules:\n      - \(ruleKind == .alerting ? "alert" : "record"): \(ruleName)\n        expr: \(expr)\n"
        if ruleKind == .alerting {
            if !forDuration.isEmpty { yaml += "        for: \(forDuration)\n" }
            yaml += "        labels:\n"
            if severity != "none" { yaml += "          severity: \(severity)\n" }
            if !summary.isEmpty || !ruleDescription.isEmpty {
                yaml += "        annotations:\n"
                if !summary.isEmpty { yaml += "          summary: \(summary)\n" }
                if !ruleDescription.isEmpty { yaml += "          description: \(ruleDescription)\n" }
            }
        }
        return yaml
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if mode == .guided {
                guidedContent
            } else {
                yamlContent
            }
            Divider()
            footerBar
        }
        .frame(width: 700, height: 560)
        .background(t.surface)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text("Create Rule")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 0) {
                modeTabButton(label: "Guided", target: .guided)
                modeTabButton(label: "YAML", target: .yaml)
            }
            .background(t.surfaceAlt)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(t.border, lineWidth: 1))
            .cornerRadius(7)
            Spacer()
            Button("Close") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(t.surfaceAlt)
    }

    @ViewBuilder
    private func modeTabButton(label: String, target: SheetMode) -> some View {
        let isActive = mode == target
        Button { mode = target } label: {
            Text(label)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(isActive ? t.btnAccBg : Color.clear)
                .foregroundColor(isActive ? t.btnAccFg : t.textMuted)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var guidedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                formSection.padding(20)
                Divider().padding(.horizontal, 20)
                yamlPreviewSection.padding(20)
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            formRow(label: "Rule Type") {
                Picker("", selection: $ruleKind) {
                    Text("Alerting").tag(RuleKind.alerting)
                    Text("Recording").tag(RuleKind.recording)
                }
                .pickerStyle(.menu).frame(width: 160).labelsHidden()
            }
            formRow(label: "Namespace", required: true) {
                styledTextField("e.g. production", text: $namespace)
            }
            formRow(label: "Group Name", required: true) {
                styledTextField("e.g. node-alerts", text: $groupName)
            }
            formRow(label: "Rule Name", required: true) {
                styledTextField(ruleKind == .alerting ? "e.g. HighCPU" : "e.g. job:cpu_usage:rate5m", text: $ruleName)
            }
            formRow(label: "PromQL Expression", required: true) {
                TextEditor(text: $expr)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(t.textSub)
                    .frame(height: 80)
                    .padding(6)
                    .background(t.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.border, lineWidth: 1))
                    .cornerRadius(6)
            }
            if ruleKind == .alerting {
                Divider().padding(.vertical, 4)
                formRow(label: "For (duration)") {
                    styledTextField("e.g. 5m", text: $forDuration).frame(width: 160)
                }
                formRow(label: "Severity") {
                    Picker("", selection: $severity) {
                        Text("critical").tag("critical")
                        Text("warning").tag("warning")
                        Text("info").tag("info")
                        Text("none").tag("none")
                    }
                    .pickerStyle(.menu).frame(width: 160).labelsHidden()
                }
                formRow(label: "Summary") {
                    styledTextField("Short description of the alert", text: $summary)
                }
                formRow(label: "Description") {
                    styledTextField("Detailed description or runbook link", text: $ruleDescription)
                }
            }
        }
    }

    private var yamlPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YAML PREVIEW")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.7)
            ScrollView {
                Text(guidedRequiredFilled ? generateYAML() : "Fill in the required fields to see a preview.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(guidedRequiredFilled ? t.textSub : t.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .frame(height: 100)
            .background(t.inputBg)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.border, lineWidth: 1))
            .cornerRadius(6)
        }
    }

    private var yamlContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PASTE RAW YAML")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.7)
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
            TextEditor(text: $rawYAML)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(t.textSub)
                .padding(8)
                .background(t.inputBg)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.border, lineWidth: 1))
                .cornerRadius(6)
                .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerBar: some View {
        HStack {
            Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            Spacer()
            Button("Push to Mimir") {
                let yaml = mode == .guided ? generateYAML() : rawYAML
                onPush(yaml)
                dismiss()
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(!canPush)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(t.surfaceAlt)
    }

    @ViewBuilder
    private func formRow<Content: View>(
        label: String,
        required: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 2) {
                Text(label).font(.system(size: 12)).foregroundColor(t.labelText)
                if required {
                    Text("*").font(.system(size: 12)).foregroundColor(Color(hex: "#f87171"))
                }
            }
            .frame(width: 160, alignment: .trailing)
            content().frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(t.textSub)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(t.inputBg)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.border, lineWidth: 1))
            .cornerRadius(6)
    }
}
