import XCTest
@testable import MimirToolUI

struct MockAlertsService: AlertsFetching {
    var stubbedAlerts: [MimirAlert] = []
    var stubbedError: AlertsServiceError? = nil

    func fetch(for env: MimirEnvironment) async throws -> [MimirAlert] {
        if let error = stubbedError { throw error }
        return stubbedAlerts
    }
}

@MainActor
final class AlertsViewModelTests: XCTestCase {

    private func makeAlert(name: String, state: MimirAlert.AlertState) -> MimirAlert {
        MimirAlert(labels: ["alertname": name], state: state, activeAt: nil)
    }

    func test_load_populatesAlerts() async {
        var svc = MockAlertsService()
        svc.stubbedAlerts = [makeAlert(name: "HighCPU", state: .firing)]
        let vm = AlertsViewModel(service: svc, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertEqual(vm.alerts.count, 1)
        XCTAssertNil(vm.errorMessage)
    }

    func test_filter_firing() async {
        var svc = MockAlertsService()
        svc.stubbedAlerts = [
            makeAlert(name: "A", state: .firing),
            makeAlert(name: "B", state: .pending),
            makeAlert(name: "C", state: .inactive)
        ]
        let vm = AlertsViewModel(service: svc, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        vm.filter = .firing
        XCTAssertEqual(vm.filtered.count, 1)
        XCTAssertEqual(vm.filtered.first?.labels["alertname"], "A")
    }

    func test_filter_pending() async {
        var svc = MockAlertsService()
        svc.stubbedAlerts = [
            makeAlert(name: "A", state: .firing),
            makeAlert(name: "B", state: .pending)
        ]
        let vm = AlertsViewModel(service: svc, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        vm.filter = .pending
        XCTAssertEqual(vm.filtered.count, 1)
        XCTAssertEqual(vm.filtered.first?.labels["alertname"], "B")
    }

    func test_filter_all_returnsAllAlerts() async {
        var svc = MockAlertsService()
        svc.stubbedAlerts = [
            makeAlert(name: "A", state: .firing),
            makeAlert(name: "B", state: .pending),
            makeAlert(name: "C", state: .inactive)
        ]
        let vm = AlertsViewModel(service: svc, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        vm.filter = .all
        XCTAssertEqual(vm.filtered.count, 3)
    }

    func test_firingCount() async {
        var svc = MockAlertsService()
        svc.stubbedAlerts = [
            makeAlert(name: "A", state: .firing),
            makeAlert(name: "B", state: .firing),
            makeAlert(name: "C", state: .pending)
        ]
        let vm = AlertsViewModel(service: svc, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertEqual(vm.firingCount, 2)
    }

    func test_load_setsErrorOnFailure() async {
        var svc = MockAlertsService()
        svc.stubbedError = .httpError(statusCode: 500, body: "internal error")
        let vm = AlertsViewModel(service: svc, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.alerts.isEmpty)
    }

    func test_lastRefreshed_setAfterLoad() async {
        let vm = AlertsViewModel(service: MockAlertsService(), environment: MimirEnvironment(name: "T", url: "http://x"))
        XCTAssertNil(vm.lastRefreshed)
        await vm.load()
        XCTAssertNotNil(vm.lastRefreshed)
    }

    func test_autoRefresh_defaultsFalse() {
        let vm = AlertsViewModel(service: MockAlertsService(), environment: MimirEnvironment(name: "T", url: "http://x"))
        XCTAssertFalse(vm.autoRefresh)
    }

    func test_isLoading_falseAfterLoad() async {
        let vm = AlertsViewModel(service: MockAlertsService(), environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertFalse(vm.isLoading)
    }
}
