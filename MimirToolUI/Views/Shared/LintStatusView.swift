import SwiftUI

/// Compact strip shown between editor toolbar and content.
/// Shows YAML validity state from the linter.
struct LintStatusView: View {
    let diagnostics: [YAMLDiagnostic]
    let isChecking: Bool
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        HStack(spacing: 6) {
            if isChecking {
                ProgressView().scaleEffect(0.55).frame(width: 14, height: 14)
                Text("Checking…")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } else if diagnostics.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#4ade80"))
                Text("Valid YAML")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "#4ade80"))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#f87171"))
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(diagnostics.prefix(3)) { d in
                        HStack(spacing: 4) {
                            if d.line > 0 {
                                Text("Line \(d.line):")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "#f87171"))
                            }
                            Text(d.message)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#f87171"))
                                .lineLimit(1)
                        }
                    }
                    if diagnostics.count > 3 {
                        Text("+ \(diagnostics.count - 3) more")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(lintBg)
        .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)
        .animation(.easeInOut(duration: 0.15), value: diagnostics.count)
        .animation(.easeInOut(duration: 0.15), value: isChecking)
    }

    private var lintBg: Color {
        if isChecking || diagnostics.isEmpty { return t.surfaceAlt }
        return t.isDark ? Color(hex: "#1e0f0f") : Color(hex: "#fff5f5")
    }
}
