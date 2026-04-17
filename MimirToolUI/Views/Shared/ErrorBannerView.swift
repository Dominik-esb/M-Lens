import SwiftUI

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color(hex: "#f87171"))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#f87171"))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").foregroundColor(.gray)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(hex: "#261212"))
        .cornerRadius(8)
        .padding(.horizontal, 4)
    }
}
