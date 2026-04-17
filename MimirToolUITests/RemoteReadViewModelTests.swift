import XCTest
@testable import MimirToolUI

@MainActor
final class RemoteReadViewModelTests: XCTestCase {

    func test_runQuery_setsErrorOnEmptySelector() async {
        let vm = RemoteReadViewModel(runner: MockRunner(), environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.selector = ""
        await vm.runQuery()
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_runQuery_doesNotCallRunnerWhenSelectorEmpty() async {
        let mock = MockRunner()
        let vm = RemoteReadViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.selector = ""
        await vm.runQuery()
        XCTAssertTrue(mock.allCapturedArgs.isEmpty)
    }

    func test_runQuery_callsCorrectArgs() async {
        let mock = MockRunner()
        let vm = RemoteReadViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.selector = "{job=\"node\"}"
        await vm.runQuery()
        let args = mock.capturedArgs
        XCTAssertTrue(args.contains("remote-read"))
        XCTAssertTrue(args.contains("export"))
        XCTAssertTrue(args.contains("--selector"))
        XCTAssertTrue(args.contains("{job=\"node\"}"))
        XCTAssertTrue(args.contains("--from"))
        XCTAssertTrue(args.contains("--to"))
        XCTAssertTrue(args.contains("--output-file"))
    }

    func test_exportCSV_writesCorrectContent() throws {
        let vm = RemoteReadViewModel(runner: MockRunner(), environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.results = [
            RemoteReadResult(metricName: "cpu_total", labels: ["job": "node"], latestValue: "0.85", timestamp: "1700000000")
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-export-\(Int(Date().timeIntervalSince1970)).csv")
        try vm.exportCSV(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("metric,labels,value,timestamp\n"))
        XCTAssertTrue(content.contains("cpu_total"))
        XCTAssertTrue(content.contains("0.85"))
        XCTAssertTrue(content.contains("1700000000"))
    }

    func test_exportCSV_emptyResultsWritesHeaderOnly() throws {
        let vm = RemoteReadViewModel(runner: MockRunner(), environment: MimirEnvironment(name: "T", url: "http://x"))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-export-empty-\(Int(Date().timeIntervalSince1970)).csv")
        try vm.exportCSV(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "metric,labels,value,timestamp\n")
    }

    func test_isLoading_falseAfterQuery() async {
        let mock = MockRunner()
        let vm = RemoteReadViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.selector = "{job=\"node\"}"
        await vm.runQuery()
        XCTAssertFalse(vm.isLoading)
    }
}
