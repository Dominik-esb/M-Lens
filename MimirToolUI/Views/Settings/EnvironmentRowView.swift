import SwiftUI

struct EnvironmentRowView: View {
    let environment: MimirEnvironment
    let isActive: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? Color(hex: "#4ade80") : Color(hex: "#444444"))
                .frame(width: 8, height: 8)
            Text(environment.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#d0d0d0"))
                .frame(width: 110, alignment: .leading)
            if isActive {
                Text("active")
                    .font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Color(hex: "#142e14")).foregroundColor(Color(hex: "#4ade80"))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#1e4020"), lineWidth: 1))
                    .cornerRadius(4)
            }
            Text(environment.url)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#555555"))
                .lineLimit(1)
            Spacer()
            Text(environment.orgID ?? "—")
                .font(.system(size: 11)).foregroundColor(Color(hex: "#444444"))
                .frame(width: 90, alignment: .trailing)
            HStack(spacing: 5) {
                Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(IconButtonStyle())
                Button(action: onDelete) { Image(systemName: "xmark") }.buttonStyle(IconButtonStyle(danger: true))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }
}
