import SwiftUI

struct RuleEditorSheet: View {
    @Binding var yaml: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var hasChanges = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Rule").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Push to Mimir") { onSave(yaml); dismiss() }.buttonStyle(AccentButtonStyle())
            }
            .padding(16)
            .background(Color(hex: "#1a1a1a"))

            YAMLEditorView(text: $yaml, hasChanges: $hasChanges)
        }
        .frame(width: 640, height: 480)
        .background(Color(hex: "#1e1e1e"))
    }
}
