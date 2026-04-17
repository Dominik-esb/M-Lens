import SwiftUI

struct RuleEditorSheet: View {
    @Binding var yaml: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }
    @State private var hasChanges = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Rule").font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Push to Mimir") { onSave(yaml); dismiss() }.buttonStyle(AccentButtonStyle())
            }
            .padding(16)
            .background(t.surfaceAlt)

            YAMLEditorView(text: $yaml, hasChanges: $hasChanges)
        }
        .frame(width: 640, height: 480)
        .background(t.surface)
    }
}
