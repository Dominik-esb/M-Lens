import SwiftUI

struct SidebarView: View {
    @Binding var selectedPage: AppPage
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @EnvironmentObject var envStore: EnvironmentStore
    @State private var showEnvPopover = false
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Environment chip
            Button { showEnvPopover.toggle() } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(envStore.activeEnvironment != nil ? Color(hex: "#4ade80") : t.textFaint)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(envStore.activeEnvironment?.name ?? "No Environment")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(t.envNameFg)
                        Text(envStore.activeEnvironment?.url ?? "Add one in Settings")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(t.chipBg)
                .cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(t.borderSub, lineWidth: 1))
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
            Divider()
            HStack(spacing: 8) {
                Text("mimirtool")
                    .font(.system(size: 10))
                    .foregroundColor(t.footerFg)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isDarkMode.toggle() }
                } label: {
                    Image(systemName: isDarkMode ? "sun.max" : "moon")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 220)
        .background(t.sidebarBg)
    }

    @ViewBuilder
    private func navItem(_ page: AppPage, icon: String, label: String) -> some View {
        let isActive = selectedPage == page
        Button { selectedPage = page } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundColor(isActive ? Color(hex: "#7ab3f0") : t.navInactiveIcon)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? Color(hex: "#7ab3f0") : t.navInactiveFg)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isActive ? t.navActiveBg : Color.clear)
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
            .foregroundColor(t.sectionLabelFg)
            .tracking(0.8)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }
}
