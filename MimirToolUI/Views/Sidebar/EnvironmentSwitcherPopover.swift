import SwiftUI

struct EnvironmentSwitcherPopover: View {
    @EnvironmentObject var envStore: EnvironmentStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Switch Environment")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12).padding(.top, 10)

            ForEach(envStore.environments) { env in
                Button {
                    envStore.setActive(env)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(envStore.activeEnvironment?.id == env.id ? Color(hex: "#4ade80") : Color.gray)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(env.name).font(.system(size: 13, weight: .medium))
                            Text(env.url).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if envStore.activeEnvironment?.id == env.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#7ab3f0"))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }

            if envStore.environments.isEmpty {
                Text("No environments. Add one in Settings.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .padding(12)
            }
        }
        .frame(width: 260)
        .padding(.bottom, 8)
    }
}
