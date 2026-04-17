import Foundation
import Combine

@MainActor
final class EnvironmentStore: ObservableObject {
    @Published private(set) var environments: [MimirEnvironment] = []
    @Published private(set) var activeEnvironment: MimirEnvironment?

    private let storageURL: URL

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        load()
    }

    static func defaultStorageURL() -> URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("MimirToolUI")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("environments.json")
    }

    func add(_ env: MimirEnvironment) {
        environments.append(env)
        if environments.count == 1 { activeEnvironment = env }
        save()
    }

    func delete(_ env: MimirEnvironment) {
        environments.removeAll { $0.id == env.id }
        if activeEnvironment?.id == env.id {
            activeEnvironment = environments.first
        }
        save()
    }

    func update(_ env: MimirEnvironment) {
        guard let idx = environments.firstIndex(where: { $0.id == env.id }) else { return }
        environments[idx] = env
        if activeEnvironment?.id == env.id { activeEnvironment = env }
        save()
    }

    func setActive(_ env: MimirEnvironment) {
        guard environments.contains(where: { $0.id == env.id }) else { return }
        activeEnvironment = env
    }

    func save() {
        guard let data = try? JSONEncoder().encode(environments) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let envs = try? JSONDecoder().decode([MimirEnvironment].self, from: data) else { return }
        environments = envs
        activeEnvironment = envs.first
    }
}
