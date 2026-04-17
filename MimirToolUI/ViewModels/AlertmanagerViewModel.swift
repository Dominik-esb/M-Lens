import Foundation

@MainActor
final class AlertmanagerViewModel: ObservableObject {
    @Published var configYAML: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasUnsavedChanges = false

    private let runner: MimirtoolRunning
    private let environment: MimirEnvironment

    init(runner: MimirtoolRunning, environment: MimirEnvironment) {
        self.runner = runner
        self.environment = environment
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            configYAML = try await runner.run(["alertmanager", "get"], environment: environment)
            hasUnsavedChanges = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func push() async {
        errorMessage = nil
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("alertmanager-push.yaml")
        do {
            try configYAML.write(to: file, atomically: true, encoding: .utf8)
            _ = try await runner.run(["alertmanager", "load", file.path], environment: environment)
            hasUnsavedChanges = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async {
        errorMessage = nil
        do {
            _ = try await runner.run(["alertmanager", "delete"], environment: environment)
            configYAML = ""
            hasUnsavedChanges = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
