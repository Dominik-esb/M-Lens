import XCTest
@testable import MimirToolUI

final class ModelsTests: XCTestCase {

    func test_environment_roundtrips_json() throws {
        let env = MimirEnvironment(
            id: UUID(),
            name: "Prod",
            url: "https://mimir.example.com",
            orgID: "ops",
            extraHeaders: ["X-Custom": "val"],
            tlsSkipVerify: false,
            caCertPath: nil,
            timeout: "30s",
            retries: 3
        )
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(MimirEnvironment.self, from: data)
        XCTAssertEqual(decoded.name, "Prod")
        XCTAssertEqual(decoded.orgID, "ops")
        XCTAssertEqual(decoded.extraHeaders, ["X-Custom": "val"])
        XCTAssertEqual(decoded.retries, 3)
    }

    func test_appSettings_roundtrips_json() throws {
        let s = AppSettings(mimirtoolPath: "/usr/local/bin/mimirtool", logLevel: "debug", verboseOutput: true)
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.logLevel, "debug")
        XCTAssertTrue(decoded.verboseOutput)
        XCTAssertEqual(decoded.mimirtoolPath, "/usr/local/bin/mimirtool")
    }

    func test_alert_decodes_state_firing() throws {
        let json = """
        {
          "labels": {"alertname": "HighCPU", "severity": "critical"},
          "state": "firing",
          "activeAt": "2026-04-17T08:00:00Z"
        }
        """.data(using: .utf8)!
        let alert = try JSONDecoder().decode(MimirAlert.self, from: json)
        XCTAssertEqual(alert.labels["alertname"], "HighCPU")
        XCTAssertEqual(alert.state, .firing)
    }

    func test_alert_decodes_state_pending() throws {
        let json = """
        {"labels": {"alertname": "DiskFull"}, "state": "pending", "activeAt": null}
        """.data(using: .utf8)!
        let alert = try JSONDecoder().decode(MimirAlert.self, from: json)
        XCTAssertEqual(alert.state, .pending)
        XCTAssertNil(alert.activeAt)
    }

    func test_environment_defaults() {
        let env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        XCTAssertNil(env.orgID)
        XCTAssertEqual(env.timeout, "30s")
        XCTAssertEqual(env.retries, 3)
        XCTAssertFalse(env.tlsSkipVerify)
        XCTAssertTrue(env.extraHeaders.isEmpty)
    }
}
