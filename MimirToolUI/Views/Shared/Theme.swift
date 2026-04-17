import SwiftUI
import AppKit

/// Adaptive color palette. Instantiate via `Theme(colorScheme)` inside a view body.
struct Theme {
    let isDark: Bool
    init(_ cs: ColorScheme) { isDark = cs == .dark }

    // MARK: - Backgrounds
    var bg: Color           { isDark ? .hex("#242424") : .hex("#f5f5f7") }
    var surface: Color      { isDark ? .hex("#1e1e1e") : .hex("#ffffff") }
    var surfaceAlt: Color   { isDark ? .hex("#1a1a1a") : .hex("#f0f0f2") }
    var inputBg: Color      { isDark ? .hex("#272727") : .hex("#f0f0f2") }
    var rowHover: Color     { isDark ? .hex("#232323") : .hex("#f5f5f7") }
    var searchBg: Color     { isDark ? .hex("#1e1e1e") : .hex("#f0f0f2") }

    // MARK: - Borders & dividers
    var border: Color       { isDark ? .hex("#2e2e2e") : .hex("#e0e0e2") }
    var borderSub: Color    { isDark ? .hex("#333333") : .hex("#d0d0d2") }
    var headerLine: Color   { isDark ? .hex("#2a2a2a") : .hex("#e5e5e7") }
    var sectionLine: Color  { isDark ? .hex("#272727") : .hex("#e8e8ea") }
    var rowLine: Color      { isDark ? .hex("#242424") : .hex("#ebebed") }
    var divider: Color      { isDark ? .hex("#252525") : .hex("#ebebed") }

    // MARK: - Text (use .primary / .secondary where possible)
    var textBody: Color     { isDark ? .hex("#d0d0d0") : .hex("#2a2a2a") }
    var textSub: Color      { isDark ? .hex("#c8c8c8") : .hex("#3a3a3a") }
    var textMuted: Color    { isDark ? .hex("#888888") : .hex("#6e6e73") }
    var textFaint: Color    { isDark ? .hex("#555555") : .hex("#86868b") }
    var textDim: Color      { isDark ? .hex("#444444") : .hex("#aaaaac") }
    var textStatus: Color   { isDark ? .hex("#3a3a3a") : .hex("#6e6e73") }
    var labelText: Color    { isDark ? .hex("#aaaaaa") : .hex("#3a3a3a") }
    var iconColor: Color    { isDark ? .hex("#666666") : .hex("#8a8a8e") }

    // MARK: - Status bar
    var statusBarBg: Color  { isDark ? .hex("#1a1a1a") : .hex("#f0f0f2") }

    // MARK: - Error banner
    var errorBg: Color      { isDark ? .hex("#261212") : .hex("#fff5f5") }

    // MARK: - Sidebar
    var sidebarBg: Color    { isDark ? .hex("#1e1e1e") : .hex("#ebebed") }
    var chipBg: Color       { isDark ? .hex("#2a2a2a") : .hex("#e0e0e2") }
    var navActiveBg: Color  { isDark ? .hex("#2b3f5c") : .hex("#dceeff") }
    var envNameFg: Color    { isDark ? .hex("#e8e8e8") : .hex("#1a1a1a") }
    var sectionLabelFg: Color { isDark ? .hex("#4a4a4a") : .hex("#86868b") }
    var footerFg: Color     { isDark ? .hex("#3a3a3a") : .hex("#aaaaac") }
    var navInactiveFg: Color { isDark ? .hex("#888888") : .hex("#555555") }
    var navInactiveIcon: Color { isDark ? .hex("#777777") : .hex("#888888") }

    // MARK: - Tag backgrounds
    var tagNsBg: Color      { isDark ? .hex("#1a2c40") : .hex("#dbeafe") }
    var tagAlertBg: Color   { isDark ? .hex("#2e1515") : .hex("#fee2e2") }
    var tagRecordBg: Color  { isDark ? .hex("#142e14") : .hex("#dcfce7") }
    var tagPendBg: Color    { isDark ? .hex("#2a2000") : .hex("#fef9c3") }

    // MARK: - Buttons (for ButtonStyles using @Environment(\.colorScheme))
    var btnSecBg: Color     { isDark ? .hex("#2e2e2e") : .hex("#e8e8ea") }
    var btnSecFg: Color     { isDark ? .hex("#bbbbbb") : .hex("#3a3a3a") }
    var btnSecBorder: Color { isDark ? .hex("#3a3a3a") : .hex("#d0d0d2") }
    var btnAccBg: Color     { isDark ? .hex("#1e3a6e") : .hex("#dceeff") }
    var btnAccFg: Color     { .hex("#7ab3f0") }
    var btnAccBorder: Color { isDark ? .hex("#2a4d8a") : .hex("#7ab3f0") }
    var btnDanBg: Color     { isDark ? .hex("#2e1515") : .hex("#fff0f0") }
    var btnDanFg: Color     { .hex("#f87171") }
    var btnDanBorder: Color { isDark ? .hex("#4a2020") : .hex("#f87171") }
    var iconBtnBorder: Color { isDark ? .hex("#333333") : .hex("#d0d0d2") }
    var iconBtnDanBorder: Color { isDark ? .hex("#4a2020") : .hex("#fca5a5") }

    // MARK: - YAML editor (NSColor)
    var editorBg: NSColor   { isDark ? .init(red: 0.118, green: 0.118, blue: 0.118, alpha: 1) : .white }
    var editorFg: NSColor   { isDark ? .init(red: 0.784, green: 0.784, blue: 0.784, alpha: 1) : .init(red: 0.15, green: 0.15, blue: 0.15, alpha: 1) }
}

extension Color {
    static func hex(_ value: String) -> Color { Color(hex: value) }
}
