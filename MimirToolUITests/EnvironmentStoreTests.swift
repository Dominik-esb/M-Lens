import XCTest
@testable import MimirToolUI

@MainActor
final class EnvironmentStoreTests: XCTestCase {
    var store: EnvironmentStore!
    var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        store = EnvironmentStore(storageURL: tempURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL)
        try await super.tearDown()
    }

    func test_addEnvironment_appearsInList() {
        let env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        XCTAssertEqual(store.environments.count, 1)
        XCTAssertEqual(store.environments.first?.name, "Dev")
    }

    func test_addFirstEnvironment_becomesActive() {
        let env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        XCTAssertEqual(store.activeEnvironment?.name, "Dev")
    }

    func test_addSecondEnvironment_doesNotChangeActive() {
        let first = MimirEnvironment(name: "A", url: "http://a")
        let second = MimirEnvironment(name: "B", url: "http://b")
        store.add(first)
        store.add(second)
        XCTAssertEqual(store.activeEnvironment?.name, "A")
    }

    func test_deleteEnvironment_removesFromList() {
        let env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        store.delete(env)
        XCTAssertTrue(store.environments.isEmpty)
    }

    func test_deleteActiveEnvironment_activatesFirstRemaining() {
        let a = MimirEnvironment(name: "A", url: "http://a")
        let b = MimirEnvironment(name: "B", url: "http://b")
        store.add(a); store.add(b)
        store.setActive(a)
        store.delete(a)
        XCTAssertEqual(store.activeEnvironment?.name, "B")
    }

    func test_deleteLastEnvironment_activeBecomesNil() {
        let env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        store.delete(env)
        XCTAssertNil(store.activeEnvironment)
    }

    func test_updateEnvironment_changesName() {
        var env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        env.name = "Development"
        store.update(env)
        XCTAssertEqual(store.environments.first?.name, "Development")
    }

    func test_updateActiveEnvironment_updatesActiveReference() {
        var env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        env.name = "Development"
        store.update(env)
        XCTAssertEqual(store.activeEnvironment?.name, "Development")
    }

    func test_setActive_changesActiveEnvironment() {
        let a = MimirEnvironment(name: "A", url: "http://a")
        let b = MimirEnvironment(name: "B", url: "http://b")
        store.add(a); store.add(b)
        store.setActive(b)
        XCTAssertEqual(store.activeEnvironment?.name, "B")
    }

    func test_setActive_withUnknownEnv_doesNotChange() {
        let a = MimirEnvironment(name: "A", url: "http://a")
        store.add(a)
        let unknown = MimirEnvironment(name: "Unknown", url: "http://x")
        store.setActive(unknown)
        XCTAssertEqual(store.activeEnvironment?.name, "A")
    }

    func test_persistsAndLoads() {
        let env = MimirEnvironment(name: "Prod", url: "https://mimir.example.com", orgID: "ops")
        store.add(env)
        store.save()

        let loaded = EnvironmentStore(storageURL: tempURL)
        XCTAssertEqual(loaded.environments.count, 1)
        XCTAssertEqual(loaded.environments.first?.name, "Prod")
        XCTAssertEqual(loaded.environments.first?.orgID, "ops")
    }

    func test_persistsMultipleAndLoads() {
        store.add(MimirEnvironment(name: "A", url: "http://a"))
        store.add(MimirEnvironment(name: "B", url: "http://b"))
        store.save()

        let loaded = EnvironmentStore(storageURL: tempURL)
        XCTAssertEqual(loaded.environments.count, 2)
        XCTAssertEqual(loaded.environments.first?.name, "A")
    }
}
