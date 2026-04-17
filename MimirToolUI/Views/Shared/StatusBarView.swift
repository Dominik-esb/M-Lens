import SwiftUI

struct StatusBarView: View {
    let environment: MimirEnvironment?
    let statusText: String
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(environment != nil ? Color(hex: "#4ade80") : Color.gray)
                .frame(width: 6, height: 6)
            if let env = environment {
                Text("Connected · \(env.name)")
                    .foregroundColor(t.textStatus)
                if let org = env.orgID, !org.isEmpty {
                    Text("· org-id: \(org)").foregroundColor(t.textStatus)
                }
            }
            Spacer()
            Text(statusText).foregroundColor(t.textStatus)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(t.statusBarBg)
    }
}
