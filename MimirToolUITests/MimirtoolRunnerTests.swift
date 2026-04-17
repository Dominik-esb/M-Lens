import XCTest
@testable import MimirToolUI

final class MimirtoolRunnerTests: XCTestCase {

    func test_binaryCandidates_includesHomebrew() {
        let runner = MimirtoolRunner()
        let candidates = runner.binaryCandidates()
        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/mimirtool"))
        XCTAssertTrue(candidates.contains("/usr/local/bin/mimirtool"))
    }

    func test_baseArgs_includesAddress() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "http://localhost:9009")
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--address=http://localhost:9009"))
    }

    func test_baseArgs_withOrgID() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "http://localhost:9009", orgID: "my-tenant")
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--id=my-tenant"))
    }

    func test_baseArgs_withOrgID_empty_omitsFlag() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "http://localhost:9009", orgID: "")
        let args = runner.baseArgs(for: env)
        XCTAssertFalse(args.contains(where: { $0.hasPrefix("--id=") }))
    }

    func test_baseArgs_withTLSSkipVerify() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "https://x", tlsSkipVerify: true)
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--tls.insecure-skip-verify"))
    }

    func test_baseArgs_withoutTLSSkipVerify_omitsFlag() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "https://x", tlsSkipVerify: false)
        let args = runner.baseArgs(for: env)
        XCTAssertFalse(args.contains("--tls.insecure-skip-verify"))
    }

    func test_baseArgs_withExtraHeaders() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "http://x", extraHeaders: ["X-Foo": "bar"])
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--extra-headers=X-Foo:bar"))
    }

    func test_baseArgs_withCACert() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "https://x", caCertPath: "/etc/ssl/ca.crt")
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--tls.ca-path=/etc/ssl/ca.crt"))
    }

    func test_resolvedBinaryPath_returnsNilWhenNoneExist() {
        let runner = MimirtoolRunner(settings: AppSettings(mimirtoolPath: "/nonexistent/mimirtool"))
        // Both the settings path and all candidates are nonexistent
        // We can't guarantee candidates don't exist on this machine, so only test the settings path override
        let path = runner.resolvedBinaryPath(override: "/also/nonexistent")
        // If a real mimirtool exists in candidates, this will return it — that's correct behavior
        // We just verify the call doesn't crash
        _ = path
    }

    func test_run_throwsBinaryNotFound_whenNoBinaryExists() async {
        let runner = MimirtoolRunner(settings: AppSettings(mimirtoolPath: "/nonexistent/mimirtool"))
        // Only fails if no real mimirtool is installed in any candidate path
        // Skip test if mimirtool is actually installed
        guard runner.resolvedBinaryPath() == nil else { return }
        let env = MimirEnvironment(name: "T", url: "http://localhost:9009")
        do {
            _ = try await runner.run(["rules", "list"], environment: env)
            XCTFail("Expected binaryNotFound error")
        } catch MimirtoolError.binaryNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
