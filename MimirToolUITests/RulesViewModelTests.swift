import XCTest
@testable import MimirToolUI

// Mock runner for ViewModel tests
final class MockRunner: MimirtoolRunning, @unchecked Sendable {
    var stubbedOutput: String = ""
    var stubbedError: Error? = nil
    /// The args from the most recent call.
    var capturedArgs: [String] = []
    /// All invocations in order.
    var allCapturedArgs: [[String]] = []

    func run(_ args: [String], environment: MimirEnvironment) async throws -> String {
        capturedArgs = args
        allCapturedArgs.append(args)
        if let error = stubbedError { throw error }
        return stubbedOutput
    }

    func resolvedBinaryPath(override: String?) -> String? { "/mock/mimirtool" }
}

@MainActor
final class RulesViewModelTests: XCTestCase {

    func test_load_parsesNamespacesFromOutput() async {
        let mock = MockRunner()
        mock.stubbedOutput = """
        Namespace: infra
          Group: node-alerts
            Rule: NodeHighCPU (alerting)
            Rule: cpu:usage:rate5m (recording)
        Namespace: app
          Group: latency
            Rule: HighP99Latency (alerting)
        """
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertEqual(vm.namespaces.count, 2)
        let infra = vm.namespaces.first { $0.name == "infra" }
        XCTAssertNotNil(infra)
        XCTAssertEqual(infra?.groups.first?.rules.count, 2)
    }

    func test_load_setsErrorOnFailure() async {
        let mock = MockRunner()
        mock.stubbedError = MimirtoolError.binaryNotFound
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.namespaces.isEmpty)
    }

    func test_deleteNamespace_callsCorrectArgs() async {
        let mock = MockRunner()
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.deleteNamespace("infra")
        // First call is the delete; second call is the reload triggered by load()
        XCTAssertEqual(mock.allCapturedArgs.first, ["rules", "delete", "infra"])
    }

    func test_deleteGroup_callsCorrectArgs() async {
        let mock = MockRunner()
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.deleteGroup(namespace: "infra", group: "node-alerts")
        // First call is the delete; second call is the reload triggered by load()
        XCTAssertEqual(mock.allCapturedArgs.first, ["rules", "delete", "infra", "node-alerts"])
    }

    func test_push_callsRulesLoad() async {
        let mock = MockRunner()
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.push(yamlContent: "groups: []")
        // First call is rules load; second call is the reload triggered by load()
        let firstArgs = mock.allCapturedArgs.first ?? []
        XCTAssertTrue(firstArgs.contains("rules"))
        XCTAssertTrue(firstArgs.contains("load"))
    }

    func test_filtered_bySearchText() async {
        let mock = MockRunner()
        mock.stubbedOutput = """
        Namespace: infra
          Group: alerts
            Rule: NodeHighCPU (alerting)
            Rule: DiskFull (alerting)
        """
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        vm.searchText = "CPU"
        XCTAssertEqual(vm.filtered.first?.groups.first?.rules.count, 1)
        XCTAssertEqual(vm.filtered.first?.groups.first?.rules.first?.ruleName, "NodeHighCPU")
    }

    func test_isLoading_falseAfterLoad() async {
        let mock = MockRunner()
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertFalse(vm.isLoading)
    }
}
