import SwiftUI

struct SidebarView: View {
    @Binding var selectedPage: AppPage
    @Binding var isDarkMode: Bool
    @EnvironmentObject var envStore: EnvironmentStore
    @State private var showEnvPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Environment chip
            Button { showEnvPopover.toggle() } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(envStore.activeEnvironment != nil ? Color(hex: "#4ade80") : Color(hex: "#555555"))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(envStore.activeEnvironment?.name ?? "No Environment")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#e8e8e8"))
                        Text(envStore.activeEnvironment?.url ?? "Add one in Settings")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#555555"))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "#555555"))
                }
                .padding(12)
                .background(Color(hex: "#2a2a2a"))
                .cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: "#333333"), lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .popover(isPresented: $showEnvPopover) {
                EnvironmentSwitcherPopover()
                    .environmentObject(envStore)
            }

            sectionLabel("Views").padding(.top, 12)
            navItem(.rules,        icon: "doc.text",        label: "Rules")
            navItem(.alertmanager, icon: "bell",             label: "Alertmanager")
            navItem(.alerts,       icon: "bolt",             label: "Alerts")
            navItem(.remoteRead,   icon: "magnifyingglass",  label: "Remote Read")

            sectionLabel("Tools").padding(.top, 8)
            navItem(.settings, icon: "gearshape", label: "Settings")

            Spacer()

            // Footer
            Divider().background(Color(hex: "#282828"))
            HStack(spacing: 8) {
                Text("mimirtool")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#3a3a3a"))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isDarkMode.toggle() }
                } label: {
                    Image(systemName: isDarkMode ? "sun.max" : "moon")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#555555"))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 220)
        .background(Color(hex: "#1e1e1e"))
    }

    @ViewBuilder
    private func navItem(_ page: AppPage, icon: String, label: String) -> some View {
        let isActive = selectedPage == page
        Button { selectedPage = page } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundColor(isActive ? Color(hex: "#7ab3f0") : Color(hex: "#777777"))
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? Color(hex: "#7ab3f0") : Color(hex: "#888888"))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isActive ? Color(hex: "#2b3f5c") : Color.clear)
            .cornerRadius(7)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: isActive)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color(hex: "#4a4a4a"))
            .tracking(0.8)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }
}
