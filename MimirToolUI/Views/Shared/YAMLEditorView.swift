import SwiftUI
import AppKit

struct YAMLEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var hasChanges: Bool
    var diagnostics: [YAMLDiagnostic] = []
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
        textView.allowsUndo = true
        textView.string = text
        let theme = Theme(colorScheme)
        applyColors(textView, theme: theme)
        highlight(textView, theme: theme, diagnostics: diagnostics)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        let theme = Theme(colorScheme)
        if textView.string != text {
            let sel = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(sel)
        }
        applyColors(textView, theme: theme)
        highlight(textView, theme: theme, diagnostics: diagnostics)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Colors

    private func applyColors(_ tv: NSTextView, theme: Theme) {
        tv.backgroundColor = theme.editorBg
        tv.textColor = theme.editorFg
        tv.insertionPointColor = theme.editorFg
        tv.enclosingScrollView?.backgroundColor = theme.editorBg
        tv.enclosingScrollView?.drawsBackground = true
    }

    // MARK: - Syntax highlighting + error tinting

    private func highlight(_ tv: NSTextView, theme: Theme, diagnostics: [YAMLDiagnostic]) {
        guard let storage = tv.textStorage else { return }
        let text = tv.string
        guard !text.isEmpty else { return }

        let fullNS = NSRange(text.startIndex..., in: text)
        let baseFg = theme.editorFg
        let commentColor = NSColor.systemGreen.withAlphaComponent(0.85)
        let keyColor     = NSColor.systemBlue
        let stringColor  = NSColor.systemOrange
        let anchorColor  = NSColor.systemPurple.withAlphaComponent(0.8)

        storage.beginEditing()

        // 1. Reset to base colour
        storage.addAttribute(.foregroundColor, value: baseFg, range: fullNS)

        // 2. Error-line background tint (behind everything else)
        let lines = text.components(separatedBy: "\n")
        for diag in diagnostics where diag.line > 0 {
            if let range = charRange(forLine: diag.line, in: text, lines: lines) {
                storage.addAttribute(.backgroundColor,
                                     value: NSColor.systemRed.withAlphaComponent(0.12),
                                     range: range)
            }
        }

        // 3. YAML syntax colours (applied in order so later rules win)
        applyRegex(#"#[^\n]*"#,                  color: commentColor, storage: storage, text: text)
        applyRegex(#"^(\s*)([\w_.-]+)(\s*:)"#,   color: keyColor,     storage: storage, text: text, group: 2)
        applyRegex(#""(?:[^"\\]|\\.)*""#,         color: stringColor,  storage: storage, text: text)
        applyRegex(#"'(?:[^'\\]|\\.)*'"#,         color: stringColor,  storage: storage, text: text)
        applyRegex(#"^---$|^\.\.\.$"#,            color: anchorColor,  storage: storage, text: text)

        storage.endEditing()
    }

    private func applyRegex(_ pattern: String, color: NSColor,
                            storage: NSTextStorage, text: String, group: Int = 0,
                            options: NSRegularExpression.Options = [.anchorsMatchLines]) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let full = NSRange(text.startIndex..., in: text)
        for m in re.matches(in: text, range: full) {
            let r = group < m.numberOfRanges ? m.range(at: group) : m.range
            if r.location != NSNotFound {
                storage.addAttribute(.foregroundColor, value: color, range: r)
            }
        }
    }

    private func charRange(forLine lineNumber: Int, in text: String,
                           lines: [String]) -> NSRange? {
        guard lineNumber >= 1, lineNumber <= lines.count else { return nil }
        var offset = 0
        for i in 0 ..< (lineNumber - 1) {
            offset += lines[i].utf16.count + 1   // +1 for \n
        }
        return NSRange(location: offset, length: lines[lineNumber - 1].utf16.count)
    }

    // MARK: - Coordinator

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
