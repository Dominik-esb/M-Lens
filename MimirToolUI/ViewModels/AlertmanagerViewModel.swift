import Foundation

@MainActor
final class AlertmanagerViewModel: ObservableObject {
    @Published var configYAML: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasUnsavedChanges = false
    @Published var activityMessage: ActivityMessage?

    private let runner: MimirtoolRunning
    private let environment: MimirEnvironment
    private var toastTask: Task<Void, Never>?

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
            showToast("Alertmanager config uploaded successfully", isError: false)
        } catch {
            errorMessage = error.localizedDescription
            showToast("Upload failed: \(error.localizedDescription)", isError: true)
        }
    }

    func delete() async {
        errorMessage = nil
        do {
            _ = try await runner.run(["alertmanager", "delete"], environment: environment)
            configYAML = ""
            hasUnsavedChanges = false
            showToast("Alertmanager config deleted", isError: false)
        } catch {
            errorMessage = error.localizedDescription
            showToast("Delete failed: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Toast

    private func showToast(_ text: String, isError: Bool) {
        toastTask?.cancel()
        activityMessage = ActivityMessage(text: text, isError: isError)
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            activityMessage = nil
        }
    }
}
