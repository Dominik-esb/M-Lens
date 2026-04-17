import SwiftUI

struct TagView: View {
    let text: String
    let style: TagStyle
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    enum TagStyle {
        case namespace, alerting, recording, firing, pending
        var fg: Color {
            switch self {
            case .namespace: return Color(hex: "#60a5fa")
            case .alerting, .firing: return Color(hex: "#f87171")
            case .recording: return Color(hex: "#4ade80")
            case .pending:   return Color(hex: "#fbbf24")
            }
        }
    }

    private var bg: Color {
        switch style {
        case .namespace: return t.tagNsBg
        case .alerting, .firing: return t.tagAlertBg
        case .recording: return t.tagRecordBg
        case .pending:   return t.tagPendBg
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(bg)
            .foregroundColor(style.fg)
            .cornerRadius(5)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
