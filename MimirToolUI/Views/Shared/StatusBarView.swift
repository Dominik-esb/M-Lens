import SwiftUI

struct StatusBarView: View {
    let environment: MimirEnvironment?
    let statusText: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(environment != nil ? Color(hex: "#4ade80") : Color.gray)
                .frame(width: 6, height: 6)
            if let env = environment {
                Text("Connected · \(env.name)")
                    .foregroundColor(Color(hex: "#3a3a3a"))
                if let org = env.orgID, !org.isEmpty {
                    Text("· org-id: \(org)").foregroundColor(Color(hex: "#3a3a3a"))
                }
            }
            Spacer()
            Text(statusText).foregroundColor(Color(hex: "#3a3a3a"))
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: "#1a1a1a"))
    }
}
