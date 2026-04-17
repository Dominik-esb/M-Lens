import SwiftUI

enum AppPage: Hashable {
    case rules, alertmanager, alerts, remoteRead, settings
}

struct ContentView: View {
    @EnvironmentObject var envStore: EnvironmentStore
    @State private var selectedPage: AppPage = .rules
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedPage: $selectedPage)
        } detail: {
            if selectedPage == .settings {
                SettingsView()
            } else if let env = envStore.activeEnvironment {
                detailView(for: selectedPage, env: env)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("No environment configured")
                        .foregroundStyle(.secondary)
                    Button("Open Settings") { selectedPage = .settings }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    @ViewBuilder
    private func detailView(for page: AppPage, env: MimirEnvironment) -> some View {
        switch page {
        case .rules:        RulesView(environment: env)
        case .alertmanager: AlertmanagerView(environment: env)
        case .alerts:       AlertsView(environment: env)
        case .remoteRead:   RemoteReadView(environment: env)
        case .settings:     SettingsView()
        }
    }
}
