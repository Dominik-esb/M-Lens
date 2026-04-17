import XCTest
@testable import MimirToolUI

@MainActor
final class AlertmanagerViewModelTests: XCTestCase {

    func test_load_setsConfigYAML() async {
        let mock = MockRunner()
        mock.stubbedOutput = "global:\n  resolve_timeout: 5m\n"
        let vm = AlertmanagerViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertEqual(vm.configYAML, "global:\n  resolve_timeout: 5m\n")
        XCTAssertFalse(vm.hasUnsavedChanges)
    }

    func test_load_setsErrorOnFailure() async {
        let mock = MockRunner()
        mock.stubbedError = MimirtoolError.binaryNotFound
        let vm = AlertmanagerViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_push_callsAlertmanagerLoad() async {
        let mock = MockRunner()
        let vm = AlertmanagerViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        vm.configYAML = "global:\n  resolve_timeout: 5m\n"
        await vm.push()
        XCTAssertTrue(mock.capturedArgs.contains("alertmanager"))
        XCTAssertTrue(mock.capturedArgs.contains("load"))
        XCTAssertFalse(vm.hasUnsavedChanges)
    }

    func test_delete_callsAlertmanagerDelete() async {
        let mock = MockRunner()
        mock.stubbedOutput = "global:\n  resolve_timeout: 5m\n"
        let vm = AlertmanagerViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        await vm.delete()
        XCTAssertEqual(mock.capturedArgs, ["alertmanager", "delete"])
        XCTAssertTrue(vm.configYAML.isEmpty)
    }

    func test_isLoading_falseAfterLoad() async {
        let mock = MockRunner()
        let vm = AlertmanagerViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertFalse(vm.isLoading)
    }
}
