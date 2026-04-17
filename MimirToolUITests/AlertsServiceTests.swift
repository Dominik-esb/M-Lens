import XCTest
@testable import MimirToolUI

final class AlertsServiceTests: XCTestCase {
    let service = AlertsService()

    func test_buildRequest_correctURL() throws {
        let env = MimirEnvironment(name: "T", url: "https://mimir.example.com")
        let req = try service.buildRequest(for: env)
        XCTAssertEqual(req.url?.absoluteString,
                       "https://mimir.example.com/api/prom/api/v1/alerts")
    }

    func test_buildRequest_setsOrgIDHeader() throws {
        let env = MimirEnvironment(name: "T", url: "https://mimir.example.com", orgID: "ops-team")
        let req = try service.buildRequest(for: env)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Scope-OrgID"), "ops-team")
    }

    func test_buildRequest_emptyOrgID_omitsHeader() throws {
        let env = MimirEnvironment(name: "T", url: "https://mimir.example.com", orgID: "")
        let req = try service.buildRequest(for: env)
        XCTAssertNil(req.value(forHTTPHeaderField: "X-Scope-OrgID"))
    }

    func test_buildRequest_setsExtraHeaders() throws {
        let env = MimirEnvironment(name: "T", url: "https://mimir.example.com",
                                   extraHeaders: ["X-Custom": "value123"])
        let req = try service.buildRequest(for: env)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Custom"), "value123")
    }

    func test_buildRequest_invalidURL_throws() {
        let env = MimirEnvironment(name: "T", url: "not a url !!!!")
        XCTAssertThrowsError(try service.buildRequest(for: env))
    }

    func test_parse_firingAlert() throws {
        let json = """
        {
          "status": "success",
          "data": {
            "alerts": [
              {
                "labels": {"alertname": "HighCPU", "severity": "critical"},
                "state": "firing",
                "activeAt": "2026-04-17T08:00:00Z"
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let alerts = try service.parse(data: json)
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.state, .firing)
        XCTAssertEqual(alerts.first?.labels["alertname"], "HighCPU")
    }

    func test_parse_multipleAlerts() throws {
        let json = """
        {
          "status": "success",
          "data": {
            "alerts": [
              {"labels": {"alertname": "A"}, "state": "firing", "activeAt": null},
              {"labels": {"alertname": "B"}, "state": "pending", "activeAt": null}
            ]
          }
        }
        """.data(using: .utf8)!
        let alerts = try service.parse(data: json)
        XCTAssertEqual(alerts.count, 2)
        XCTAssertEqual(alerts[0].state, .firing)
        XCTAssertEqual(alerts[1].state, .pending)
    }

    func test_parse_emptyAlerts() throws {
        let json = """
        {"status": "success", "data": {"alerts": []}}
        """.data(using: .utf8)!
        let alerts = try service.parse(data: json)
        XCTAssertEqual(alerts.count, 0)
    }

    func test_buildRequest_hasGetMethod() throws {
        let env = MimirEnvironment(name: "T", url: "https://mimir.example.com")
        let req = try service.buildRequest(for: env)
        XCTAssertEqual(req.httpMethod, "GET")
    }
}
