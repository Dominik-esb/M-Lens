import SwiftUI

struct BinaryNotFoundView: View {
    let onOpenSettings: () -> Void
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#f87171").opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(Color(hex: "#f87171"))
                }

                VStack(spacing: 6) {
                    Text("mimirtool not found")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("MimirLens needs the mimirtool binary to communicate with Mimir.\nSet the path in Settings or install it via Homebrew.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(spacing: 8) {
                    Button(action: onOpenSettings) {
                        Label("Open Settings", systemImage: "gear")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(AccentButtonStyle())

                    Text("brew install grafana/grafana/mimirtool")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(t.textMuted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(t.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.borderSub, lineWidth: 1))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
            }
            .padding(40)
            .background(t.surface)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .padding(40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.bg)
    }
}
