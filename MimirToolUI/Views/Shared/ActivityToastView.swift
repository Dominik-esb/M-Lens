import SwiftUI

struct ActivityMessage: Equatable {
    let text: String
    let isError: Bool
}

struct ActivityToastView: View {
    let message: ActivityMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(message.isError ? Color(hex: "#f87171") : Color(hex: "#4ade80"))
                .font(.system(size: 13))
            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .padding(.horizontal, 20)
    }
}
