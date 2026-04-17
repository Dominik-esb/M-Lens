import SwiftUI

@main
struct MimirToolUIApp: App {
    @StateObject private var envStore = EnvironmentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(envStore)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 640)
    }
}
