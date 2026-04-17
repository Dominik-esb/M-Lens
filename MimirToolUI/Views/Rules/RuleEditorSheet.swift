import SwiftUI

struct RuleEditorSheet: View {
    @Binding var yaml: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    @State private var hasChanges = false
    @State private var diagnostics: [YAMLDiagnostic] = []
    @State private var isChecking = false
    @State private var lintTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Rule").font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Push to Mimir") { onSave(yaml); dismiss() }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(!diagnostics.isEmpty)
            }
            .padding(16)
            .background(t.surfaceAlt)
            .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)

            // Lint status strip
            LintStatusView(diagnostics: diagnostics, isChecking: isChecking)

            YAMLEditorView(text: $yaml, hasChanges: $hasChanges, diagnostics: diagnostics)
        }
        .frame(width: 640, height: 520)
        .background(t.surface)
        .task { await runLint() }
        .onChange(of: yaml) { _ in scheduleLint() }
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
        diagnostics = await YAMLLinter.lint(yaml)
        isChecking = false
    }
}
