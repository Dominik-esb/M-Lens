import SwiftUI
import AppKit

struct YAMLEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var hasChanges: Bool
    @Environment(\.colorScheme) var colorScheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.string = text
        applyColors(to: textView, theme: Theme(colorScheme))
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text { textView.string = text }
        applyColors(to: textView, theme: Theme(colorScheme))
    }

    private func applyColors(to textView: NSTextView, theme: Theme) {
        textView.backgroundColor = theme.editorBg
        textView.textColor = theme.editorFg
        if let scrollView = textView.enclosingScrollView {
            scrollView.backgroundColor = theme.editorBg
            scrollView.drawsBackground = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: YAMLEditorView
        init(_ parent: YAMLEditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            parent.hasChanges = true
        }
    }
}
