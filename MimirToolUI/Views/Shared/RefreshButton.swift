import SwiftUI

/// Refresh button that shows a native ProgressView while loading.
/// Avoids SwiftUI rotationEffect + repeatForever glitches.
struct RefreshButton: View {
    let isLoading: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(t.iconColor)
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }
}
