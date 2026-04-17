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

    // Creates a temp dir pre-populated with YAML files for testing.
    private func makeTmpDir(namespaceYAMLs: [String: String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rules-test-\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 0..<10000))")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (ns, yaml) in namespaceYAMLs {
            try yaml.write(to: dir.appendingPathComponent("\(ns).yaml"), atomically: true, encoding: .utf8)
        }
        return dir
    }

    func test_load_parsesNamespacesFromDirectory() async throws {
        let mock = MockRunner()
        let infraYAML = """
        groups:
          - name: node-alerts
            rules:
              - alert: NodeHighCPU
                expr: cpu > 0.8
              - record: cpu:usage:rate5m
                expr: rate(cpu[5m])
        """
        let appYAML = """
        groups:
          - name: latency
            rules:
              - alert: HighP99Latency
                expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1
        """
        let dir = try makeTmpDir(namespaceYAMLs: ["infra": infraYAML, "app": appYAML])
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.tmpDirProvider = { dir }
        await vm.load()
        XCTAssertEqual(vm.namespaces.count, 2)
        let infra = vm.namespaces.first { $0.name == "infra" }
        XCTAssertNotNil(infra)
        XCTAssertEqual(infra?.groups.first?.rules.count, 2)
    }

    func test_load_usesOutputDirFlag() async {
        let mock = MockRunner()
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertTrue(mock.capturedArgs.contains("--output-dir"), "load() must pass --output-dir to runner")
        XCTAssertTrue(mock.capturedArgs.contains("rules"))
        XCTAssertTrue(mock.capturedArgs.contains("list"))
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

    func test_filtered_bySearchText() async throws {
        let mock = MockRunner()
        let yaml = """
        groups:
          - name: alerts
            rules:
              - alert: NodeHighCPU
                expr: placeholder
              - alert: DiskFull
                expr: placeholder
        """
        let dir = try makeTmpDir(namespaceYAMLs: ["infra": yaml])
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.tmpDirProvider = { dir }
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
