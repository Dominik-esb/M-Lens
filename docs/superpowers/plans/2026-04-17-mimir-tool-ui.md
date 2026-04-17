# MimirTool UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI app that wraps the `mimirtool` CLI with a dark, WailBrew-style UI for managing Mimir rules, alertmanager config, alerts, and remote read.

**Architecture:** SwiftUI + MVVM. A `MimirtoolRunner` service shells out to the `mimirtool` binary for all write/read operations. Alerts are fetched via `URLSession` directly (mimirtool has no alerts-list command). Environments and settings are persisted as JSON in `~/Library/Application Support/MimirToolUI/`.

**Tech Stack:** Swift 5.9+, SwiftUI, macOS 13+, XCTest, `Process` for shell execution, `URLSession` for alerts API.

---

## File Map

```
MimirToolUI/
  MimirToolUIApp.swift
  ContentView.swift
  Models/
    MimirEnvironment.swift
    AppSettings.swift
    RuleModels.swift
    AlertModel.swift
    RemoteReadModels.swift
  Services/
    EnvironmentStore.swift
    MimirtoolRunner.swift        # protocol + concrete impl
    AlertsService.swift
  ViewModels/
    RulesViewModel.swift
    AlertmanagerViewModel.swift
    AlertsViewModel.swift
    RemoteReadViewModel.swift
  Views/
    Sidebar/
      SidebarView.swift
      EnvironmentSwitcherPopover.swift
    Rules/
      RulesView.swift
      RuleEditorSheet.swift
    Alertmanager/
      AlertmanagerView.swift
      ConfigSummaryView.swift
    Alerts/
      AlertsView.swift
    RemoteRead/
      RemoteReadView.swift
    Settings/
      SettingsView.swift
      EnvironmentFormSheet.swift
    Shared/
      TagView.swift
      StatusBarView.swift
      ErrorBannerView.swift
      YAMLEditorView.swift
MimirToolUITests/
  MimirtoolRunnerTests.swift
  EnvironmentStoreTests.swift
  RulesViewModelTests.swift
  AlertmanagerViewModelTests.swift
  AlertsServiceTests.swift
  RemoteReadViewModelTests.swift
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `MimirToolUI.xcodeproj` (via Xcode)
- Create: `MimirToolUI/MimirToolUIApp.swift`
- Create: all subdirectories in file map above

- [ ] **Step 1: Create project in Xcode**

  File → New → Project → macOS → App.
  - Product Name: `MimirToolUI`
  - Bundle ID: `com.yourname.MimirToolUI`
  - Interface: SwiftUI
  - Language: Swift
  - Include Tests: ✓
  - Minimum deployment: macOS 13.0

- [ ] **Step 2: Create folder groups**

  In Xcode navigator, create groups: `Models`, `Services`, `ViewModels`, `Views/Sidebar`, `Views/Rules`, `Views/Alertmanager`, `Views/Alerts`, `Views/RemoteRead`, `Views/Settings`, `Views/Shared`.

- [ ] **Step 3: Add `.gitignore`**

```
xcuserdata/
*.xcuserstate
DerivedData/
.DS_Store
```

- [ ] **Step 4: Commit**

```bash
git init
git add .
git commit -m "chore: initial Xcode project"
```

---

## Task 2: Models

**Files:**
- Create: `MimirToolUI/Models/MimirEnvironment.swift`
- Create: `MimirToolUI/Models/AppSettings.swift`
- Create: `MimirToolUI/Models/RuleModels.swift`
- Create: `MimirToolUI/Models/AlertModel.swift`
- Create: `MimirToolUI/Models/RemoteReadModels.swift`
- Test: `MimirToolUITests/ModelsTests.swift`

- [ ] **Step 1: Write failing model tests**

```swift
// MimirToolUITests/ModelsTests.swift
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
    }

    func test_appSettings_roundtrips_json() throws {
        let s = AppSettings(mimirtoolPath: "/usr/local/bin/mimirtool", logLevel: "debug", verboseOutput: true)
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.logLevel, "debug")
        XCTAssertTrue(decoded.verboseOutput)
    }

    func test_alert_decodes_from_prometheus_json() throws {
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
}
```

- [ ] **Step 2: Run — expect compile failure (types don't exist yet)**

```bash
xcodebuild test -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep -E "error:|PASSED|FAILED"
```

- [ ] **Step 3: Implement models**

```swift
// MimirToolUI/Models/MimirEnvironment.swift
import Foundation

struct MimirEnvironment: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var orgID: String?
    var extraHeaders: [String: String]
    var tlsSkipVerify: Bool
    var caCertPath: String?
    var timeout: String
    var retries: Int

    init(id: UUID = UUID(), name: String, url: String, orgID: String? = nil,
         extraHeaders: [String: String] = [:], tlsSkipVerify: Bool = false,
         caCertPath: String? = nil, timeout: String = "30s", retries: Int = 3) {
        self.id = id; self.name = name; self.url = url; self.orgID = orgID
        self.extraHeaders = extraHeaders; self.tlsSkipVerify = tlsSkipVerify
        self.caCertPath = caCertPath; self.timeout = timeout; self.retries = retries
    }
}
```

```swift
// MimirToolUI/Models/AppSettings.swift
import Foundation

struct AppSettings: Codable {
    var mimirtoolPath: String?
    var logLevel: String
    var verboseOutput: Bool

    init(mimirtoolPath: String? = nil, logLevel: String = "info", verboseOutput: Bool = false) {
        self.mimirtoolPath = mimirtoolPath
        self.logLevel = logLevel
        self.verboseOutput = verboseOutput
    }
}
```

```swift
// MimirToolUI/Models/RuleModels.swift
import Foundation

struct RuleNamespace: Identifiable {
    var id: String { name }
    let name: String
    var groups: [RuleGroup]
}

struct RuleGroup: Identifiable {
    var id: String { "\(namespace)/\(name)" }
    let namespace: String
    let name: String
    var rules: [Rule]
}

struct Rule: Identifiable {
    var id: String { "\(group)/\(ruleName)" }
    let group: String
    let ruleName: String
    let type: RuleType
    let yaml: String   // raw YAML for the rule
    var namespace: String = ""

    enum RuleType: String { case alerting, recording }
}
```

```swift
// MimirToolUI/Models/AlertModel.swift
import Foundation

struct MimirAlert: Codable, Identifiable {
    var id: String { labels["alertname"] ?? UUID().uuidString }
    let labels: [String: String]
    let state: AlertState
    let activeAt: String?

    enum AlertState: String, Codable {
        case firing, pending, inactive
    }
}

struct AlertsAPIResponse: Codable {
    let status: String
    let data: [MimirAlert]
}
```

```swift
// MimirToolUI/Models/RemoteReadModels.swift
import Foundation

struct RemoteReadResult: Identifiable {
    let id = UUID()
    let metricName: String
    let labels: [String: String]
    let latestValue: String
    let timestamp: String
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep -E "error:|PASSED|FAILED|passed|failed"
```

Expected: all 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add MimirToolUI/Models/ MimirToolUITests/ModelsTests.swift
git commit -m "feat: add core data models"
```

---

## Task 3: MimirtoolRunner

**Files:**
- Create: `MimirToolUI/Services/MimirtoolRunner.swift`
- Test: `MimirToolUITests/MimirtoolRunnerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// MimirToolUITests/MimirtoolRunnerTests.swift
import XCTest
@testable import MimirToolUI

final class MimirtoolRunnerTests: XCTestCase {
    func test_detectsBinaryAtHomebrew() {
        // Arrange: we only assert the detection logic, not actual filesystem
        let runner = MimirtoolRunner()
        let candidates = runner.binaryCandidates()
        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/mimirtool"))
        XCTAssertTrue(candidates.contains("/usr/local/bin/mimirtool"))
    }

    func test_buildsCorrectArguments_withOrgID() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "http://localhost:9009", orgID: "my-tenant")
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--address=http://localhost:9009"))
        XCTAssertTrue(args.contains("--id=my-tenant"))
    }

    func test_buildsCorrectArguments_withTLSSkipVerify() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "https://mimir.example.com", tlsSkipVerify: true)
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--tls.insecure-skip-verify"))
    }

    func test_buildsCorrectArguments_withExtraHeaders() {
        let runner = MimirtoolRunner()
        let env = MimirEnvironment(name: "T", url: "http://x", extraHeaders: ["X-Foo": "bar"])
        let args = runner.baseArgs(for: env)
        XCTAssertTrue(args.contains("--extra-headers=X-Foo:bar"))
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

```bash
xcodebuild test -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep "error:"
```

- [ ] **Step 3: Implement MimirtoolRunner**

```swift
// MimirToolUI/Services/MimirtoolRunner.swift
import Foundation

// Protocol enables mocking in ViewModel tests
protocol MimirtoolRunning {
    func run(_ args: [String], environment: MimirEnvironment) async throws -> String
    func resolvedBinaryPath(override: String?) -> String?
}

enum MimirtoolError: LocalizedError {
    case binaryNotFound
    case executionFailed(exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "mimirtool binary not found. Please set the path in Settings."
        case .executionFailed(let code, let stderr):
            return "mimirtool exited \(code): \(stderr)"
        }
    }
}

final class MimirtoolRunner: MimirtoolRunning {
    private let settings: AppSettings

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func binaryCandidates() -> [String] {
        [
            "/opt/homebrew/bin/mimirtool",
            "/usr/local/bin/mimirtool",
            "/usr/bin/mimirtool",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/.local/bin/mimirtool"
        ]
    }

    func resolvedBinaryPath(override: String? = nil) -> String? {
        if let override, !override.isEmpty, FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        return binaryCandidates().first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func baseArgs(for env: MimirEnvironment) -> [String] {
        var args: [String] = ["--address=\(env.url)"]
        if let orgID = env.orgID, !orgID.isEmpty {
            args.append("--id=\(orgID)")
        }
        if env.tlsSkipVerify {
            args.append("--tls.insecure-skip-verify")
        }
        if let ca = env.caCertPath, !ca.isEmpty {
            args.append("--tls.ca-path=\(ca)")
        }
        for (key, value) in env.extraHeaders {
            args.append("--extra-headers=\(key):\(value)")
        }
        return args
    }

    func run(_ args: [String], environment env: MimirEnvironment) async throws -> String {
        guard let binary = resolvedBinaryPath(override: settings.mimirtoolPath) else {
            throw MimirtoolError.binaryNotFound
        }
        let allArgs = baseArgs(for: env) + args
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = allArgs

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            do {
                try process.run()
                process.waitUntilExit()
                let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: out)
                } else {
                    continuation.resume(throwing: MimirtoolError.executionFailed(exitCode: process.terminationStatus, stderr: err))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep -E "PASSED|FAILED|passed|failed"
```

- [ ] **Step 5: Commit**

```bash
git add MimirToolUI/Services/MimirtoolRunner.swift MimirToolUITests/MimirtoolRunnerTests.swift
git commit -m "feat: add MimirtoolRunner with binary detection and arg building"
```

---

## Task 4: EnvironmentStore

**Files:**
- Create: `MimirToolUI/Services/EnvironmentStore.swift`
- Test: `MimirToolUITests/EnvironmentStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// MimirToolUITests/EnvironmentStoreTests.swift
import XCTest
@testable import MimirToolUI

final class EnvironmentStoreTests: XCTestCase {
    var store: EnvironmentStore!
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = EnvironmentStore(storageURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func test_addEnvironment_appearsInList() {
        let env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        XCTAssertEqual(store.environments.count, 1)
        XCTAssertEqual(store.environments.first?.name, "Dev")
    }

    func test_deleteEnvironment_removesFromList() {
        let env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        store.delete(env)
        XCTAssertTrue(store.environments.isEmpty)
    }

    func test_updateEnvironment_changesName() {
        var env = MimirEnvironment(name: "Dev", url: "http://localhost:9009")
        store.add(env)
        env.name = "Development"
        store.update(env)
        XCTAssertEqual(store.environments.first?.name, "Development")
    }

    func test_persistsAndLoads() {
        let env = MimirEnvironment(name: "Prod", url: "https://mimir.example.com")
        store.add(env)
        store.save()

        let loaded = EnvironmentStore(storageURL: tempURL)
        XCTAssertEqual(loaded.environments.first?.name, "Prod")
    }

    func test_activeEnvironment_defaultsToFirst() {
        store.add(MimirEnvironment(name: "A", url: "http://a"))
        store.add(MimirEnvironment(name: "B", url: "http://b"))
        XCTAssertEqual(store.activeEnvironment?.name, "A")
    }

    func test_setActive_changesActiveEnvironment() {
        let a = MimirEnvironment(name: "A", url: "http://a")
        let b = MimirEnvironment(name: "B", url: "http://b")
        store.add(a); store.add(b)
        store.setActive(b)
        XCTAssertEqual(store.activeEnvironment?.name, "B")
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

- [ ] **Step 3: Implement EnvironmentStore**

```swift
// MimirToolUI/Services/EnvironmentStore.swift
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
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
        if activeEnvironment?.id == env.id { activeEnvironment = environments.first }
        save()
    }

    func update(_ env: MimirEnvironment) {
        if let idx = environments.firstIndex(where: { $0.id == env.id }) {
            environments[idx] = env
            if activeEnvironment?.id == env.id { activeEnvironment = env }
        }
        save()
    }

    func setActive(_ env: MimirEnvironment) {
        activeEnvironment = env
    }

    func save() {
        guard let data = try? JSONEncoder().encode(environments) else { return }
        try? data.write(to: storageURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let envs = try? JSONDecoder().decode([MimirEnvironment].self, from: data) else { return }
        environments = envs
        activeEnvironment = envs.first
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep -E "PASSED|FAILED|passed|failed"
```

- [ ] **Step 5: Commit**

```bash
git add MimirToolUI/Services/EnvironmentStore.swift MimirToolUITests/EnvironmentStoreTests.swift
git commit -m "feat: add EnvironmentStore with persistence"
```

---

## Task 5: AlertsService

**Files:**
- Create: `MimirToolUI/Services/AlertsService.swift`
- Test: `MimirToolUITests/AlertsServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// MimirToolUITests/AlertsServiceTests.swift
import XCTest
@testable import MimirToolUI

final class AlertsServiceTests: XCTestCase {
    func test_buildsCorrectURL() throws {
        let env = MimirEnvironment(name: "T", url: "https://mimir.example.com", orgID: "ops")
        let service = AlertsService()
        let request = try service.buildRequest(for: env)
        XCTAssertEqual(request.url?.absoluteString, "https://mimir.example.com/api/prom/api/v1/alerts")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Scope-OrgID"), "ops")
    }

    func test_parsesPrometheusAlertsResponse() throws {
        let json = """
        {"status":"success","data":{"alerts":[
          {"labels":{"alertname":"HighCPU","severity":"critical"},"state":"firing","activeAt":"2026-04-17T08:00:00Z","value":"1"}
        ]}}
        """.data(using: .utf8)!
        let service = AlertsService()
        let alerts = try service.parse(data: json)
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.state, .firing)
        XCTAssertEqual(alerts.first?.labels["alertname"], "HighCPU")
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

- [ ] **Step 3: Implement AlertsService**

```swift
// MimirToolUI/Services/AlertsService.swift
import Foundation

// Decodable wrapper for Prometheus /api/v1/alerts response
private struct PrometheusAlertsResponse: Decodable {
    struct Data: Decodable { let alerts: [MimirAlert] }
    let status: String
    let data: Data
}

// MimirAlert needs a flat Decodable — add CodingKeys
extension MimirAlert {
    enum CodingKeys: String, CodingKey { case labels, state, activeAt }
}

final class AlertsService {
    func buildRequest(for env: MimirEnvironment) throws -> URLRequest {
        guard let base = URL(string: env.url) else {
            throw URLError(.badURL)
        }
        let url = base.appendingPathComponent("api/prom/api/v1/alerts")
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        if let orgID = env.orgID, !orgID.isEmpty {
            req.setValue(orgID, forHTTPHeaderField: "X-Scope-OrgID")
        }
        for (k, v) in env.extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }

    func parse(data: Data) throws -> [MimirAlert] {
        let response = try JSONDecoder().decode(PrometheusAlertsResponse.self, from: data)
        return response.data.alerts
    }

    func fetch(for env: MimirEnvironment) async throws -> [MimirAlert] {
        let request = try buildRequest(for: env)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try parse(data: data)
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Commit**

```bash
git add MimirToolUI/Services/AlertsService.swift MimirToolUITests/AlertsServiceTests.swift
git commit -m "feat: add AlertsService for Prometheus alerts API"
```

---

## Task 6: ViewModels

**Files:**
- Create: `MimirToolUI/ViewModels/RulesViewModel.swift`
- Create: `MimirToolUI/ViewModels/AlertmanagerViewModel.swift`
- Create: `MimirToolUI/ViewModels/AlertsViewModel.swift`
- Create: `MimirToolUI/ViewModels/RemoteReadViewModel.swift`
- Test: `MimirToolUITests/RulesViewModelTests.swift`
- Test: `MimirToolUITests/AlertmanagerViewModelTests.swift`

- [ ] **Step 1: Write RulesViewModel tests**

```swift
// MimirToolUITests/RulesViewModelTests.swift
import XCTest
@testable import MimirToolUI

// Mock runner for tests
final class MockRunner: MimirtoolRunning {
    var stubbedOutput: String = ""
    var stubbedError: Error? = nil
    var lastArgs: [String] = []

    func run(_ args: [String], environment: MimirEnvironment) async throws -> String {
        lastArgs = args
        if let error = stubbedError { throw error }
        return stubbedOutput
    }

    func resolvedBinaryPath(override: String?) -> String? { "/mock/mimirtool" }
}

final class RulesViewModelTests: XCTestCase {
    func test_loadRules_setsNamespacesFromYAML() async {
        let mock = MockRunner()
        mock.stubbedOutput = """
        namespace: infra
        groups:
          - name: node-alerts
            rules:
              - alert: NodeHighCPU
                expr: cpu > 0.9
        """
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertFalse(vm.namespaces.isEmpty)
        XCTAssertEqual(vm.namespaces.first?.name, "infra")
    }

    func test_loadRules_setsErrorOnFailure() async {
        let mock = MockRunner()
        mock.stubbedError = MimirtoolError.binaryNotFound
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.load()
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_deleteNamespace_callsCorrectArgs() async {
        let mock = MockRunner()
        let vm = RulesViewModel(runner: mock, environment: MimirEnvironment(name: "T", url: "http://x"))
        await vm.deleteNamespace("infra")
        XCTAssertTrue(mock.lastArgs.contains("delete"))
        XCTAssertTrue(mock.lastArgs.contains("infra"))
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

- [ ] **Step 3: Implement RulesViewModel**

```swift
// MimirToolUI/ViewModels/RulesViewModel.swift
import Foundation
import Combine

@MainActor
final class RulesViewModel: ObservableObject {
    @Published var namespaces: [RuleNamespace] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private let runner: MimirtoolRunning
    private let environment: MimirEnvironment

    init(runner: MimirtoolRunning, environment: MimirEnvironment) {
        self.runner = runner
        self.environment = environment
    }

    var filtered: [RuleNamespace] {
        guard !searchText.isEmpty else { return namespaces }
        return namespaces.compactMap { ns in
            let groups = ns.groups.compactMap { g in
                let rules = g.rules.filter {
                    $0.ruleName.localizedCaseInsensitiveContains(searchText)
                }
                return rules.isEmpty ? nil : RuleGroup(namespace: g.namespace, name: g.name, rules: rules)
            }
            return groups.isEmpty ? nil : RuleNamespace(name: ns.name, groups: groups)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let output = try await runner.run(["rules", "list", "--output-dir", tmpDir()], environment: environment)
            namespaces = parseRulesOutput(output)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteNamespace(_ namespace: String) async {
        errorMessage = nil
        do {
            _ = try await runner.run(["rules", "delete", namespace], environment: environment)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroup(namespace: String, group: String) async {
        errorMessage = nil
        do {
            _ = try await runner.run(["rules", "delete", namespace, group], environment: environment)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func push(yamlContent: String) async {
        errorMessage = nil
        let file = URL(fileURLWithPath: tmpDir()).appendingPathComponent("rules-push.yaml")
        do {
            try yamlContent.write(to: file, atomically: true, encoding: .utf8)
            _ = try await runner.run(["rules", "load", file.path], environment: environment)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func tmpDir() -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MimirToolUI-rules")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    // Parse YAML output from mimirtool rules list.
    // mimirtool outputs one YAML document per namespace to the output-dir.
    // For simplicity we parse the stdout summary format.
    private func parseRulesOutput(_ output: String) -> [RuleNamespace] {
        // mimirtool rules list --output-dir writes files; stdout just lists namespace/group/rule names
        // Format: "Namespace: <name>\n  Group: <group>\n    Rule: <rule> (<type>)"
        var namespaces: [String: [String: [Rule]]] = [:]
        var currentNS = ""
        var currentGroup = ""
        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Namespace:") {
                currentNS = t.replacingOccurrences(of: "Namespace:", with: "").trimmingCharacters(in: .whitespaces)
                namespaces[currentNS] = namespaces[currentNS] ?? [:]
            } else if t.hasPrefix("Group:") {
                currentGroup = t.replacingOccurrences(of: "Group:", with: "").trimmingCharacters(in: .whitespaces)
                namespaces[currentNS]?[currentGroup] = []
            } else if t.hasPrefix("Rule:") {
                let parts = t.replacingOccurrences(of: "Rule:", with: "").trimmingCharacters(in: .whitespaces)
                let isRecording = parts.contains("(recording)")
                let name = parts.replacingOccurrences(of: "(alerting)", with: "")
                    .replacingOccurrences(of: "(recording)", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let rule = Rule(group: currentGroup, ruleName: name,
                                type: isRecording ? .recording : .alerting, yaml: "", namespace: currentNS)
                namespaces[currentNS]?[currentGroup]?.append(rule)
            }
        }
        return namespaces.map { nsName, groups in
            RuleNamespace(name: nsName, groups: groups.map { gName, rules in
                RuleGroup(namespace: nsName, name: gName, rules: rules)
            }.sorted { $0.name < $1.name })
        }.sorted { $0.name < $1.name }
    }
}
```

- [ ] **Step 4: Implement AlertmanagerViewModel**

```swift
// MimirToolUI/ViewModels/AlertmanagerViewModel.swift
import Foundation

@MainActor
final class AlertmanagerViewModel: ObservableObject {
    @Published var configYAML: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasUnsavedChanges = false

    private let runner: MimirtoolRunning
    private let environment: MimirEnvironment

    init(runner: MimirtoolRunning, environment: MimirEnvironment) {
        self.runner = runner
        self.environment = environment
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            configYAML = try await runner.run(["alertmanager", "get"], environment: environment)
            hasUnsavedChanges = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func push() async {
        errorMessage = nil
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("alertmanager-push.yaml")
        do {
            try configYAML.write(to: file, atomically: true, encoding: .utf8)
            _ = try await runner.run(["alertmanager", "load", file.path], environment: environment)
            hasUnsavedChanges = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async {
        errorMessage = nil
        do {
            _ = try await runner.run(["alertmanager", "delete"], environment: environment)
            configYAML = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 5: Implement AlertsViewModel**

```swift
// MimirToolUI/ViewModels/AlertsViewModel.swift
import Foundation
import Combine

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published var alerts: [MimirAlert] = []
    @Published var filter: AlertFilter = .all
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshed: Date?

    enum AlertFilter { case all, firing, pending }

    private let service: AlertsService
    private let environment: MimirEnvironment

    init(service: AlertsService = AlertsService(), environment: MimirEnvironment) {
        self.service = service
        self.environment = environment
    }

    var filtered: [MimirAlert] {
        alerts.filter { alert in
            let stateMatch: Bool = {
                switch filter {
                case .all: return true
                case .firing: return alert.state == .firing
                case .pending: return alert.state == .pending
                }
            }()
            let searchMatch = searchText.isEmpty ||
                alert.labels.contains { k, v in
                    "\(k)=\(v)".localizedCaseInsensitiveContains(searchText)
                }
            return stateMatch && searchMatch
        }
    }

    var firingCount: Int { alerts.filter { $0.state == .firing }.count }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            alerts = try await service.fetch(for: environment)
            lastRefreshed = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

- [ ] **Step 6: Implement RemoteReadViewModel**

```swift
// MimirToolUI/ViewModels/RemoteReadViewModel.swift
import Foundation

@MainActor
final class RemoteReadViewModel: ObservableObject {
    @Published var selector: String = ""
    @Published var fromDate: Date = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
    @Published var toDate: Date = Date()
    @Published var results: [RemoteReadResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var queryDuration: String?

    private let runner: MimirtoolRunning
    private let environment: MimirEnvironment

    init(runner: MimirtoolRunning, environment: MimirEnvironment) {
        self.runner = runner
        self.environment = environment
    }

    private var iso8601: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    func runQuery() async {
        guard !selector.isEmpty else { errorMessage = "Selector is required"; return }
        isLoading = true
        errorMessage = nil
        let start = Date()
        let outFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimir-remote-read-\(Int(Date().timeIntervalSince1970)).json")
        do {
            _ = try await runner.run([
                "remote-read", "export",
                "--selector", selector,
                "--from", iso8601.string(from: fromDate),
                "--to", iso8601.string(from: toDate),
                "--output-file", outFile.path
            ], environment: environment)
            results = try parseResults(from: outFile)
            queryDuration = String(format: "%.0fms", Date().timeIntervalSince(start) * 1000)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func exportCSV(to url: URL) throws {
        var csv = "metric,labels,value,timestamp\n"
        for r in results {
            let labels = r.labels.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ",")
            csv += "\(r.metricName),\"\(labels)\",\(r.latestValue),\(r.timestamp)\n"
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func parseResults(from url: URL) throws -> [RemoteReadResult] {
        // mimirtool remote-read export writes JSON lines: {"metric":{...},"values":[[ts,val],...]}
        let content = try String(contentsOf: url, encoding: .utf8)
        var results: [RemoteReadResult] = []
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let metric = obj["metric"] as? [String: String],
                  let values = obj["values"] as? [[Any]],
                  let last = values.last,
                  last.count == 2 else { continue }
            let name = metric["__name__"] ?? "unknown"
            let labels = metric.filter { $0.key != "__name__" }
            let ts = last[0]
            let val = last[1] as? String ?? "\(last[1])"
            results.append(RemoteReadResult(metricName: name, labels: labels,
                                            latestValue: val, timestamp: "\(ts)"))
        }
        return results
    }
}
```

- [ ] **Step 7: Run tests — expect all pass**

```bash
xcodebuild test -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep -E "PASSED|FAILED|passed|failed"
```

- [ ] **Step 8: Commit**

```bash
git add MimirToolUI/ViewModels/ MimirToolUITests/RulesViewModelTests.swift MimirToolUITests/AlertmanagerViewModelTests.swift
git commit -m "feat: add all four ViewModels"
```

---

## Task 7: Shared Views

**Files:**
- Create: `MimirToolUI/Views/Shared/TagView.swift`
- Create: `MimirToolUI/Views/Shared/StatusBarView.swift`
- Create: `MimirToolUI/Views/Shared/ErrorBannerView.swift`
- Create: `MimirToolUI/Views/Shared/YAMLEditorView.swift`

- [ ] **Step 1: TagView**

```swift
// MimirToolUI/Views/Shared/TagView.swift
import SwiftUI

struct TagView: View {
    let text: String
    let style: TagStyle

    enum TagStyle {
        case namespace, alerting, recording, firing, pending

        var bg: Color {
            switch self {
            case .namespace: return Color(hex: "#1a2c40")
            case .alerting:  return Color(hex: "#2e1515")
            case .recording: return Color(hex: "#142e14")
            case .firing:    return Color(hex: "#2e1515")
            case .pending:   return Color(hex: "#2a2000")
            }
        }
        var fg: Color {
            switch self {
            case .namespace: return Color(hex: "#60a5fa")
            case .alerting:  return Color(hex: "#f87171")
            case .recording: return Color(hex: "#4ade80")
            case .firing:    return Color(hex: "#f87171")
            case .pending:   return Color(hex: "#fbbf24")
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(style.bg)
            .foregroundColor(style.fg)
            .cornerRadius(5)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: StatusBarView**

```swift
// MimirToolUI/Views/Shared/StatusBarView.swift
import SwiftUI

struct StatusBarView: View {
    let environment: MimirEnvironment?
    let statusText: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(environment != nil ? Color(hex: "#4ade80") : Color.gray)
                .frame(width: 6, height: 6)
            if let env = environment {
                Text("Connected · \(env.name)")
                    .foregroundColor(Color(hex: "#3a3a3a"))
                if let org = env.orgID, !org.isEmpty {
                    Text("· org-id: \(org)").foregroundColor(Color(hex: "#3a3a3a"))
                }
            }
            Spacer()
            Text(statusText).foregroundColor(Color(hex: "#3a3a3a"))
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: "#1a1a1a"))
    }
}
```

- [ ] **Step 3: ErrorBannerView**

```swift
// MimirToolUI/Views/Shared/ErrorBannerView.swift
import SwiftUI

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color(hex: "#f87171"))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#f87171"))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").foregroundColor(.gray)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(hex: "#261212"))
        .cornerRadius(8)
        .padding(.horizontal, 4)
    }
}
```

- [ ] **Step 4: YAMLEditorView (NSTextView wrapper)**

```swift
// MimirToolUI/Views/Shared/YAMLEditorView.swift
import SwiftUI
import AppKit

struct YAMLEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var hasChanges: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)
        textView.textColor = NSColor(red: 0.784, green: 0.784, blue: 0.784, alpha: 1)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.string = text
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text { textView.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: YAMLEditorView
        init(_ parent: YAMLEditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            parent.hasChanges = true
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add MimirToolUI/Views/Shared/
git commit -m "feat: add shared TagView, StatusBarView, ErrorBannerView, YAMLEditorView"
```

---

## Task 8: App Shell & Sidebar

**Files:**
- Modify: `MimirToolUI/MimirToolUIApp.swift`
- Modify: `MimirToolUI/ContentView.swift`
- Create: `MimirToolUI/Views/Sidebar/SidebarView.swift`
- Create: `MimirToolUI/Views/Sidebar/EnvironmentSwitcherPopover.swift`

- [ ] **Step 1: App entry point**

```swift
// MimirToolUI/MimirToolUIApp.swift
import SwiftUI

@main
struct MimirToolUIApp: App {
    @StateObject private var envStore = EnvironmentStore()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(envStore)
                .environment(\.appSettings, settings)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 640)
    }
}

// EnvironmentKey for AppSettings
struct AppSettingsKey: EnvironmentKey {
    static let defaultValue = AppSettings()
}
extension EnvironmentValues {
    var appSettings: AppSettings {
        get { self[AppSettingsKey.self] }
        set { self[AppSettingsKey.self] = newValue }
    }
}
```

- [ ] **Step 2: ContentView with navigation**

```swift
// MimirToolUI/ContentView.swift
import SwiftUI

enum AppPage: Hashable {
    case rules, alertmanager, alerts, remoteRead, settings
}

struct ContentView: View {
    @EnvironmentObject var envStore: EnvironmentStore
    @State private var selectedPage: AppPage = .rules

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedPage: $selectedPage)
        } detail: {
            if let env = envStore.activeEnvironment {
                detailView(for: selectedPage, env: env)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 40)).foregroundColor(.secondary)
                    Text("No environment configured")
                        .foregroundColor(.secondary)
                    Button("Open Settings") { selectedPage = .settings }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(hex: "#242424"))
    }

    @ViewBuilder
    private func detailView(for page: AppPage, env: MimirEnvironment) -> some View {
        switch page {
        case .rules:        RulesView(environment: env)
        case .alertmanager: AlertmanagerView(environment: env)
        case .alerts:       AlertsView(environment: env)
        case .remoteRead:   RemoteReadView(environment: env)
        case .settings:     SettingsView()
        }
    }
}
```

- [ ] **Step 3: SidebarView**

```swift
// MimirToolUI/Views/Sidebar/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Binding var selectedPage: AppPage
    @EnvironmentObject var envStore: EnvironmentStore
    @State private var showEnvPopover = false
    @State private var alertsCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Environment chip
            Button { showEnvPopover.toggle() } label: {
                HStack(spacing: 10) {
                    Circle().fill(Color(hex: "#4ade80")).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(envStore.activeEnvironment?.name ?? "No Environment")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#e8e8e8"))
                        Text(envStore.activeEnvironment?.url ?? "")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#555555"))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("⌄").foregroundColor(Color(hex: "#555555"))
                }
                .padding(12)
                .background(Color(hex: "#2a2a2a"))
                .cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: "#333333"), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .popover(isPresented: $showEnvPopover) {
                EnvironmentSwitcherPopover()
                    .environmentObject(envStore)
            }

            sectionLabel("Views").padding(.top, 12)
            navItem(.rules, icon: "doc.text", label: "Rules")
            navItem(.alertmanager, icon: "bell", label: "Alertmanager")
            navItem(.alerts, icon: "bolt", label: "Alerts", badge: alertsCount > 0 ? "\(alertsCount)" : nil, badgeFiring: true)
            navItem(.remoteRead, icon: "magnifyingglass", label: "Remote Read")

            sectionLabel("Tools").padding(.top, 8)
            navItem(.settings, icon: "gearshape", label: "Settings")

            Spacer()

            Divider().background(Color(hex: "#282828"))
            HStack {
                Text("↺ Refresh").font(.system(size: 12)).foregroundColor(Color(hex: "#555555"))
                Spacer()
                Text("⌘⇧R").font(.system(size: 10)).foregroundColor(Color(hex: "#3a3a3a"))
            }.padding(.horizontal, 16).padding(.vertical, 6)
            HStack {
                Text("mimirtool").font(.system(size: 10)).foregroundColor(Color(hex: "#3a3a3a"))
                Spacer()
                Button { toggleAppearance() } label: {
                    Image(systemName: "sun.max").foregroundColor(Color(hex: "#555555"))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.bottom, 10)
        }
        .frame(width: 230)
        .background(Color(hex: "#1e1e1e"))
    }

    @ViewBuilder
    private func navItem(_ page: AppPage, icon: String, label: String, badge: String? = nil, badgeFiring: Bool = false) -> some View {
        let isActive = selectedPage == page
        Button { selectedPage = page } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundColor(isActive ? Color(hex: "#7ab3f0") : Color(hex: "#777777"))
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? Color(hex: "#7ab3f0") : Color(hex: "#888888"))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(badgeFiring && !badge.isEmpty ? Color(hex: "#2e1515") : Color(hex: "#2e2e2e"))
                        .foregroundColor(badgeFiring && !badge.isEmpty ? Color(hex: "#f87171") : Color(hex: "#666666"))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isActive ? Color(hex: "#2b3f5c") : Color.clear)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color(hex: "#4a4a4a"))
            .tracking(0.8)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }

    private func toggleAppearance() {
        NSApp.appearance = NSApp.appearance == NSAppearance(named: .darkAqua)
            ? nil : NSAppearance(named: .darkAqua)
    }
}
```

- [ ] **Step 4: EnvironmentSwitcherPopover**

```swift
// MimirToolUI/Views/Sidebar/EnvironmentSwitcherPopover.swift
import SwiftUI

struct EnvironmentSwitcherPopover: View {
    @EnvironmentObject var envStore: EnvironmentStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Switch Environment")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12).padding(.top, 10)

            ForEach(envStore.environments) { env in
                Button {
                    envStore.setActive(env)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(envStore.activeEnvironment?.id == env.id ? Color(hex: "#4ade80") : Color.gray)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(env.name).font(.system(size: 13, weight: .medium))
                            Text(env.url).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if envStore.activeEnvironment?.id == env.id {
                            Image(systemName: "checkmark").font(.system(size: 11)).foregroundColor(Color(hex: "#7ab3f0"))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }

            if envStore.environments.isEmpty {
                Text("No environments. Add one in Settings.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .padding(12)
            }
        }
        .frame(width: 260)
        .padding(.bottom, 8)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add MimirToolUI/MimirToolUIApp.swift MimirToolUI/ContentView.swift MimirToolUI/Views/Sidebar/
git commit -m "feat: app shell, navigation, sidebar, environment switcher"
```

---

## Task 9: Rules View

**Files:**
- Create: `MimirToolUI/Views/Rules/RulesView.swift`
- Create: `MimirToolUI/Views/Rules/RuleEditorSheet.swift`

- [ ] **Step 1: RulesView**

```swift
// MimirToolUI/Views/Rules/RulesView.swift
import SwiftUI
import UniformTypeIdentifiers

struct RulesView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: RulesViewModel
    @State private var showEditor = false
    @State private var editingYAML = ""
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: (namespace: String, group: String?)? = nil
    @State private var showFilePicker = false

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: RulesViewModel(
            runner: MimirtoolRunner(),
            environment: environment
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text("Rules").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Color(hex: "#666666"))
                }.buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "#555555"))
                    TextField("Search…", text: $vm.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#c8c8c8"))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(Color(hex: "#1e1e1e"))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#333333"), lineWidth: 1))
                .frame(width: 200)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            // Action bar
            HStack(spacing: 8) {
                Button { showFilePicker = true } label: {
                    Label("Upload YAML", systemImage: "arrow.up").font(.system(size: 12))
                }
                .buttonStyle(SecondaryButtonStyle())
                .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.yaml, .init(filenameExtension: "yml")!]) { result in
                    if case .success(let url) = result {
                        let yaml = (try? String(contentsOf: url)) ?? ""
                        Task { await vm.push(yamlContent: yaml) }
                    }
                }

                Button { editingYAML = "groups:\n  - name: new-group\n    rules: []\n"; showEditor = true } label: {
                    Label("New Rule", systemImage: "plus").font(.system(size: 12))
                }
                .buttonStyle(AccentButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            // Error banner
            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }.padding(.horizontal, 20)
            }

            // Table
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("NAMESPACE").tableHeader(); Spacer()
                    Text("GROUP").tableHeader().frame(width: 160, alignment: .leading)
                    Text("RULE NAME").tableHeader().frame(width: 220, alignment: .leading)
                    Text("TYPE").tableHeader().frame(width: 90, alignment: .leading)
                    Text("ACTIONS").tableHeader().frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(hex: "#1e1e1e"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filtered) { ns in
                            ForEach(ns.groups) { group in
                                ForEach(group.rules) { rule in
                                    RuleRowView(rule: rule,
                                        onEdit: { editingYAML = rule.yaml; showEditor = true },
                                        onDelete: { deleteTarget = (ns.name, group.name); showDeleteConfirm = true }
                                    )
                                }
                            }
                        }
                    }
                }

                StatusBarView(
                    environment: environment,
                    statusText: "\(vm.namespaces.flatMap(\.groups).flatMap(\.rules).count) rules · \(vm.namespaces.count) namespaces"
                )
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
        .task { await vm.load() }
        .sheet(isPresented: $showEditor) {
            RuleEditorSheet(yaml: $editingYAML) { yaml in
                Task { await vm.push(yamlContent: yaml) }
            }
        }
        .alert("Delete Rule?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let t = deleteTarget {
                    Task {
                        if let group = t.group { await vm.deleteGroup(namespace: t.namespace, group: group) }
                        else { await vm.deleteNamespace(t.namespace) }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct RuleRowView: View {
    let rule: Rule
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TagView(text: rule.namespace, style: .namespace)
            Spacer()
            Text(rule.group).font(.system(size: 13)).foregroundColor(Color(hex: "#c8c8c8")).frame(width: 160, alignment: .leading)
            Text(rule.ruleName).font(.system(size: 13)).foregroundColor(Color(hex: "#c8c8c8")).frame(width: 220, alignment: .leading).lineLimit(1)
            TagView(text: rule.type.rawValue, style: rule.type == .alerting ? .alerting : .recording).frame(width: 90, alignment: .leading)
            HStack(spacing: 5) {
                Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(IconButtonStyle())
                Button(action: onDelete) { Image(systemName: "xmark") }.buttonStyle(IconButtonStyle(danger: true))
            }.frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }
}

// MARK: - Button Styles

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color(hex: "#2e2e2e"))
            .foregroundColor(Color(hex: "#bbbbbb"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#3a3a3a"), lineWidth: 1))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color(hex: "#1e3a6e"))
            .foregroundColor(Color(hex: "#7ab3f0"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#2a4d8a"), lineWidth: 1))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct IconButtonStyle: ButtonStyle {
    var danger = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 26, height: 26)
            .background(configuration.isPressed ? (danger ? Color(hex: "#2e1515") : Color(hex: "#2a2a2a")) : Color.clear)
            .foregroundColor(danger ? Color(hex: "#f87171") : Color(hex: "#666666"))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(danger ? Color(hex: "#4a2020") : Color(hex: "#333333"), lineWidth: 1))
            .cornerRadius(6)
    }
}

extension View {
    func tableHeader() -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: "#555555"))
            .textCase(.uppercase)
            .tracking(0.7)
    }
}

extension UTType {
    static var yaml: UTType { UTType(filenameExtension: "yaml") ?? .plainText }
}
```

- [ ] **Step 2: RuleEditorSheet**

```swift
// MimirToolUI/Views/Rules/RuleEditorSheet.swift
import SwiftUI

struct RuleEditorSheet: View {
    @Binding var yaml: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var hasChanges = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Rule").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Push to Mimir") { onSave(yaml); dismiss() }.buttonStyle(AccentButtonStyle())
            }
            .padding(16)
            .background(Color(hex: "#1a1a1a"))

            YAMLEditorView(text: $yaml, hasChanges: $hasChanges)
        }
        .frame(width: 640, height: 480)
        .background(Color(hex: "#1e1e1e"))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add MimirToolUI/Views/Rules/
git commit -m "feat: Rules view with table, editor sheet, upload, delete"
```

---

## Task 10: Alertmanager View

**Files:**
- Create: `MimirToolUI/Views/Alertmanager/AlertmanagerView.swift`
- Create: `MimirToolUI/Views/Alertmanager/ConfigSummaryView.swift`

- [ ] **Step 1: ConfigSummaryView**

```swift
// MimirToolUI/Views/Alertmanager/ConfigSummaryView.swift
import SwiftUI

struct ConfigSummaryView: View {
    let yaml: String

    // Minimal parse — just pull out receiver names and route matchers from raw YAML text
    private var receivers: [String] {
        yaml.components(separatedBy: "\n")
            .filter { $0.contains("name:") && !$0.contains("alertname") }
            .compactMap { line -> String? in
                let parts = line.components(separatedBy: "name:")
                guard parts.count > 1 else { return nil }
                return parts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONFIG SUMMARY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#555555"))
                .tracking(0.7)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#1a1a1a"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summarySection("Receivers") {
                        ForEach(receivers, id: \.self) { name in
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: "#7ab3f0")).frame(width: 6, height: 6)
                                Text(name).font(.system(size: 12)).foregroundColor(Color(hex: "#c0c0c0"))
                            }
                        }
                        if receivers.isEmpty {
                            Text("—").font(.system(size: 12)).foregroundColor(Color(hex: "#444444"))
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(Color(hex: "#1e1e1e"))
        .frame(width: 220)
    }

    @ViewBuilder
    private func summarySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .600))
                .foregroundColor(Color(hex: "#555555"))
                .tracking(0.6)
            content()
        }
    }
}
```

- [ ] **Step 2: AlertmanagerView**

```swift
// MimirToolUI/Views/Alertmanager/AlertmanagerView.swift
import SwiftUI
import UniformTypeIdentifiers

struct AlertmanagerView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: AlertmanagerViewModel
    @State private var showDeleteConfirm = false
    @State private var showFilePicker = false

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: AlertmanagerViewModel(
            runner: MimirtoolRunner(),
            environment: environment
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text("Alertmanager").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Color(hex: "#666666"))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            // Action bar
            HStack(spacing: 8) {
                Button { showFilePicker = true } label: {
                    Label("Upload Config", systemImage: "arrow.up").font(.system(size: 12))
                }
                .buttonStyle(SecondaryButtonStyle())
                .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.yaml]) { result in
                    if case .success(let url) = result {
                        vm.configYAML = (try? String(contentsOf: url)) ?? ""
                        vm.hasUnsavedChanges = true
                    }
                }

                Button { Task { await vm.push() } } label: {
                    Label("Push to Mimir", systemImage: "arrow.up.circle").font(.system(size: 12))
                }.buttonStyle(AccentButtonStyle())

                Spacer()

                Button { showDeleteConfirm = true } label: {
                    Label("Delete Config", systemImage: "trash").font(.system(size: 12))
                }.buttonStyle(DangerButtonStyle())
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }.padding(.horizontal, 20).padding(.bottom, 8)
            }

            // Split pane
            HStack(spacing: 12) {
                // Editor card
                VStack(spacing: 0) {
                    HStack {
                        Text("alertmanager.yaml").font(.system(size: 12)).foregroundColor(Color(hex: "#888888"))
                        Spacer()
                        if vm.hasUnsavedChanges {
                            Text("Unsaved changes").font(.system(size: 11)).foregroundColor(Color(hex: "#fbbf24"))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(hex: "#1a1a1a"))
                    .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                    YAMLEditorView(text: $vm.configYAML, hasChanges: $vm.hasUnsavedChanges)

                    StatusBarView(environment: environment,
                                  statusText: "\(vm.configYAML.components(separatedBy: "\n").count) lines")
                }
                .background(Color(hex: "#1e1e1e"))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

                // Summary panel
                ConfigSummaryView(yaml: vm.configYAML)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
        .task { await vm.load() }
        .alert("Delete Alertmanager Config?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await vm.delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the alertmanager configuration for this environment.")
        }
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color(hex: "#2e1515"))
            .foregroundColor(Color(hex: "#f87171"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#4a2020"), lineWidth: 1))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add MimirToolUI/Views/Alertmanager/
git commit -m "feat: Alertmanager view with YAML editor and config summary"
```

---

## Task 11: Alerts & Remote Read Views

**Files:**
- Create: `MimirToolUI/Views/Alerts/AlertsView.swift`
- Create: `MimirToolUI/Views/RemoteRead/RemoteReadView.swift`

- [ ] **Step 1: AlertsView**

```swift
// MimirToolUI/Views/Alerts/AlertsView.swift
import SwiftUI

struct AlertsView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: AlertsViewModel

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: AlertsViewModel(environment: environment))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Alerts").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Color(hex: "#666666"))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            // Filter chips + search
            HStack(spacing: 8) {
                filterChip("All (\(vm.alerts.count))", active: vm.filter == .all, color: Color(hex: "#2b3f5c"), fg: Color(hex: "#7ab3f0")) { vm.filter = .all }
                filterChip("Firing (\(vm.alerts.filter{$0.state == .firing}.count))", active: vm.filter == .firing, color: Color(hex: "#2e1515"), fg: Color(hex: "#f87171")) { vm.filter = .firing }
                filterChip("Pending (\(vm.alerts.filter{$0.state == .pending}.count))", active: vm.filter == .pending, color: Color(hex: "#2a2000"), fg: Color(hex: "#fbbf24")) { vm.filter = .pending }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "#555555"))
                    TextField("Filter by label…", text: $vm.searchText).textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(Color(hex: "#c8c8c8"))
                }
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(Color(hex: "#1e1e1e"))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#333333"), lineWidth: 1))
                .frame(width: 200)
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }.padding(.horizontal, 20).padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("ALERT NAME").tableHeader().frame(width: 180, alignment: .leading)
                    Text("STATE").tableHeader().frame(width: 90, alignment: .leading)
                    Text("LABELS").tableHeader()
                    Spacer()
                    Text("DURATION").tableHeader().frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(hex: "#1e1e1e"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filtered) { alert in
                            AlertRowView(alert: alert)
                        }
                    }
                }

                StatusBarView(environment: environment,
                              statusText: vm.lastRefreshed.map { "Last refreshed: \(timeAgo($0))" } ?? "")
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
        .task { await vm.load() }
    }

    @ViewBuilder
    private func filterChip(_ label: String, active: Bool, color: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 12)).padding(.horizontal, 12).padding(.vertical, 4)
                .background(active ? color : Color(hex: "#2a2a2a"))
                .foregroundColor(active ? fg : Color(hex: "#888888"))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? fg.opacity(0.3) : Color(hex: "#333333"), lineWidth: 1))
                .cornerRadius(16)
        }.buttonStyle(.plain)
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSinceNow)
        if s < 10 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        return "\(s/60)m ago"
    }
}

private struct AlertRowView: View {
    let alert: MimirAlert

    var body: some View {
        HStack(alignment: .top) {
            Text(alert.labels["alertname"] ?? "unknown")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#c8c8c8"))
                .frame(width: 180, alignment: .leading)

            TagView(text: alert.state.rawValue, style: alert.state == .firing ? .firing : .pending)
                .frame(width: 90, alignment: .leading)

            FlowLayout(spacing: 4) {
                ForEach(alert.labels.filter { $0.key != "alertname" }.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                    Text("\(k)=\(v)")
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color(hex: "#252525"))
                        .foregroundColor(Color(hex: "#666666"))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#303030"), lineWidth: 1))
                        .cornerRadius(4)
                }
            }

            Spacer()
            Text(durationString(from: alert.activeAt))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#666666"))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }

    private func durationString(from activeAt: String?) -> String {
        guard let str = activeAt,
              let date = ISO8601DateFormatter().date(from: str) else { return "—" }
        let s = Int(-date.timeIntervalSinceNow)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s/60)m" }
        return "\(s/3600)h \((s%3600)/60)m"
    }
}

// Simple flow layout for label pills
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
```

- [ ] **Step 2: RemoteReadView**

```swift
// MimirToolUI/Views/RemoteRead/RemoteReadView.swift
import SwiftUI

struct RemoteReadView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: RemoteReadViewModel
    @State private var showSavePanel = false

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: RemoteReadViewModel(
            runner: MimirtoolRunner(),
            environment: environment
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Remote Read").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }.padding(.horizontal, 20).padding(.bottom, 8)
            }

            // Query form card
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text("SELECTOR").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555")).tracking(0.7).frame(width: 80, alignment: .leading)
                    TextField("""
{job="node-exporter"}
""", text: $vm.selector)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "#d0d0d0"))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(hex: "#272727"))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                        .cornerRadius(7)
                }
                HStack(spacing: 12) {
                    Text("FROM").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555")).tracking(0.7).frame(width: 80, alignment: .leading)
                    DatePicker("", selection: $vm.fromDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().colorScheme(.dark)
                    Text("TO").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555")).tracking(0.7).frame(width: 30, alignment: .center)
                    DatePicker("", selection: $vm.toDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().colorScheme(.dark)
                }
                HStack {
                    Spacer()
                    Button { exportCSV() } label: {
                        Label("Export CSV", systemImage: "arrow.down").font(.system(size: 12))
                    }.buttonStyle(SecondaryButtonStyle())
                    Button { Task { await vm.runQuery() } } label: {
                        Label(vm.isLoading ? "Running…" : "Run Query", systemImage: "play.fill").font(.system(size: 12))
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(vm.isLoading)
                }
            }
            .padding(16)
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 12)

            // Results card
            VStack(spacing: 0) {
                HStack {
                    Text("RESULTS").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555")).tracking(0.7)
                    Spacer()
                    if !vm.results.isEmpty {
                        Text("\(vm.results.count) series").font(.system(size: 11)).foregroundColor(Color(hex: "#444444"))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#1a1a1a"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                HStack {
                    Text("METRIC").tableHeader().frame(width: 180, alignment: .leading)
                    Text("LABELS").tableHeader()
                    Spacer()
                    Text("VALUE").tableHeader().frame(width: 80, alignment: .trailing)
                    Text("TIMESTAMP").tableHeader().frame(width: 140, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#1e1e1e"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.results) { r in
                            HStack {
                                Text(r.metricName)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(hex: "#7ab3f0"))
                                    .frame(width: 180, alignment: .leading).lineLimit(1)
                                Text(r.labels.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ", "))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "#888888"))
                                    .lineLimit(1)
                                Spacer()
                                Text(r.latestValue)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(hex: "#a8d8a8"))
                                    .frame(width: 80, alignment: .trailing)
                                Text(r.timestamp)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "#555555"))
                                    .frame(width: 140, alignment: .trailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
                        }
                        if vm.results.isEmpty && !vm.isLoading {
                            Text("Run a query to see results")
                                .foregroundColor(Color(hex: "#444444"))
                                .padding(32)
                        }
                    }
                }

                StatusBarView(environment: environment, statusText: vm.queryDuration.map { "Queried in \($0)" } ?? "")
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "remote-read-export.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? vm.exportCSV(to: url)
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add MimirToolUI/Views/Alerts/ MimirToolUI/Views/RemoteRead/
git commit -m "feat: Alerts and Remote Read views"
```

---

## Task 12: Settings View

**Files:**
- Create: `MimirToolUI/Views/Settings/SettingsView.swift`
- Create: `MimirToolUI/Views/Settings/EnvironmentFormSheet.swift`
- Create: `MimirToolUI/Views/Settings/EnvironmentRowView.swift`

- [ ] **Step 1: EnvironmentFormSheet**

```swift
// MimirToolUI/Views/Settings/EnvironmentFormSheet.swift
import SwiftUI

struct EnvironmentFormSheet: View {
    @Binding var environment: MimirEnvironment
    let title: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Save") { onSave(); dismiss() }.buttonStyle(AccentButtonStyle())
            }
            .padding(16).background(Color(hex: "#1a1a1a"))

            Form {
                Section("Connection") {
                    formRow("Name", placeholder: "Production") { TextField("", text: $environment.name).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0")) }
                    formRow("URL", placeholder: "https://mimir.example.com") { TextField("", text: $environment.url).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0")).font(.system(size: 13, design: .monospaced)) }
                    formRow("Org / Tenant ID") { TextField("", text: Binding(get: { environment.orgID ?? "" }, set: { environment.orgID = $0.isEmpty ? nil : $0 })).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0")) }
                }
                Section("TLS") {
                    Toggle("Skip TLS Verify", isOn: $environment.tlsSkipVerify)
                    formRow("CA Cert Path") {
                        HStack {
                            TextField("", text: Binding(get: { environment.caCertPath ?? "" }, set: { environment.caCertPath = $0.isEmpty ? nil : $0 })).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                            Button("Browse…") { pickFile { environment.caCertPath = $0 } }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                Section("Connection") {
                    formRow("Timeout") { TextField("30s", text: $environment.timeout).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0")) }
                    formRow("Retries") { TextField("3", value: $environment.retries, format: .number).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0")) }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#1e1e1e"))
        }
        .frame(width: 480, height: 520)
        .background(Color(hex: "#1e1e1e"))
    }

    @ViewBuilder
    private func formRow<Content: View>(_ label: String, placeholder: String = "", @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).foregroundColor(Color(hex: "#aaaaaa")).frame(width: 130, alignment: .leading)
            content()
        }
    }

    private func pickFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { completion(url.path) }
    }
}
```

- [ ] **Step 2: EnvironmentRowView**

```swift
// MimirToolUI/Views/Settings/EnvironmentRowView.swift
import SwiftUI

struct EnvironmentRowView: View {
    let environment: MimirEnvironment
    let isActive: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? Color(hex: "#4ade80") : Color(hex: "#444444"))
                .frame(width: 8, height: 8)
            Text(environment.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#d0d0d0"))
                .frame(width: 110, alignment: .leading)
            if isActive {
                Text("active").font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Color(hex: "#142e14")).foregroundColor(Color(hex: "#4ade80"))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#1e4020"), lineWidth: 1))
                    .cornerRadius(4)
            }
            Text(environment.url)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#555555"))
                .lineLimit(1)
            Spacer()
            Text(environment.orgID ?? "—").font(.system(size: 11)).foregroundColor(Color(hex: "#444444")).frame(width: 90, alignment: .trailing)
            HStack(spacing: 5) {
                Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(IconButtonStyle())
                Button(action: onDelete) { Image(systemName: "xmark") }.buttonStyle(IconButtonStyle(danger: true))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }
}
```

- [ ] **Step 3: SettingsView**

```swift
// MimirToolUI/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var envStore: EnvironmentStore
    @AppStorage("mimirtoolPath") private var mimirtoolPath: String = ""
    @AppStorage("logLevel") private var logLevel: String = "info"
    @AppStorage("verboseOutput") private var verboseOutput: Bool = false
    @AppStorage("tlsSkipVerify") private var tlsSkipVerify: Bool = false
    @AppStorage("caCertPath") private var caCertPath: String = ""
    @AppStorage("timeout") private var timeout: String = "30s"
    @AppStorage("retries") private var retries: Int = 3

    @State private var showAddEnv = false
    @State private var editingEnv: MimirEnvironment?
    @State private var newEnv = MimirEnvironment(name: "", url: "")
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: MimirEnvironment?

    private var detectedPath: String? { MimirtoolRunner().resolvedBinaryPath(override: nil) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                    .padding(.top, 20)

                // Environments
                settingsCard {
                    cardHeader("Environments") {
                        Button("+ Add Environment") { newEnv = MimirEnvironment(name: "", url: ""); showAddEnv = true }
                            .buttonStyle(.plain).foregroundColor(Color(hex: "#7ab3f0")).font(.system(size: 12))
                    }
                    ForEach(envStore.environments) { env in
                        EnvironmentRowView(
                            environment: env,
                            isActive: envStore.activeEnvironment?.id == env.id,
                            onEdit: { editingEnv = env },
                            onDelete: { deleteTarget = env; showDeleteConfirm = true }
                        )
                    }
                    if envStore.environments.isEmpty {
                        Text("No environments yet.")
                            .font(.system(size: 13)).foregroundColor(Color(hex: "#444444"))
                            .padding(16)
                    }
                }

                // Binary
                settingsCard {
                    cardHeader("mimirtool Binary") {}
                    settingRow(label: "Binary Path", description: "Auto-detected or custom") {
                        HStack(spacing: 8) {
                            TextField("/path/to/mimirtool", text: $mimirtoolPath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color(hex: "#d0d0d0"))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(hex: "#272727"))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                                .cornerRadius(7)
                            if detectedPath != nil && mimirtoolPath.isEmpty {
                                Text("✓ detected").font(.system(size: 11))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color(hex: "#142e14")).foregroundColor(Color(hex: "#4ade80"))
                                    .cornerRadius(4)
                            }
                            Button("Browse…") { pickFile { mimirtoolPath = $0 } }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }

                // TLS & Connection
                settingsCard {
                    cardHeader("TLS & Connection") {}
                    settingRow(label: "Skip TLS Verify", description: "Insecure — skip cert check") {
                        Toggle("", isOn: $tlsSkipVerify).labelsHidden()
                    }
                    settingRow(label: "CA Cert Path", description: "Custom CA certificate") {
                        HStack(spacing: 8) {
                            TextField("", text: $caCertPath).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                                .font(.system(size: 13, design: .monospaced))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(hex: "#272727"))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                                .cornerRadius(7)
                            Button("Browse…") { pickFile { caCertPath = $0 } }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    settingRow(label: "Timeout", description: "Request timeout") {
                        TextField("30s", text: $timeout)
                            .textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: "#272727"))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                            .cornerRadius(7)
                            .frame(width: 120)
                    }
                    settingRow(label: "Retries", description: "Max retry attempts") {
                        TextField("3", value: $retries, format: .number)
                            .textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: "#272727"))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                            .cornerRadius(7)
                            .frame(width: 120)
                    }
                }

                // General
                settingsCard {
                    cardHeader("General") {}
                    settingRow(label: "Log Level") {
                        Picker("", selection: $logLevel) {
                            Text("info").tag("info")
                            Text("debug").tag("debug")
                            Text("warn").tag("warn")
                            Text("error").tag("error")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .colorScheme(.dark)
                    }
                    settingRow(label: "Verbose Output", description: "Show raw mimirtool output") {
                        Toggle("", isOn: $verboseOutput).labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(Color(hex: "#242424"))
        .sheet(isPresented: $showAddEnv) {
            EnvironmentFormSheet(environment: $newEnv, title: "Add Environment") {
                guard !newEnv.name.isEmpty && !newEnv.url.isEmpty else { return }
                envStore.add(newEnv)
            }
        }
        .sheet(item: $editingEnv) { env in
            let binding = Binding(
                get: { editingEnv ?? env },
                set: { editingEnv = $0 }
            )
            EnvironmentFormSheet(environment: binding, title: "Edit Environment") {
                if let updated = editingEnv { envStore.update(updated) }
            }
        }
        .alert("Delete Environment?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let t = deleteTarget { envStore.delete(t) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
    }

    @ViewBuilder
    private func cardHeader(_ title: String, @ViewBuilder action: () -> some View) -> some View {
        HStack {
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555")).tracking(0.7)
            Spacer()
            action()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(hex: "#1a1a1a"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#272727")), alignment: .bottom)
    }

    @ViewBuilder
    private func settingRow<Content: View>(label: String, description: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13)).foregroundColor(Color(hex: "#aaaaaa"))
                if let desc = description {
                    Text(desc).font(.system(size: 11)).foregroundColor(Color(hex: "#4a4a4a"))
                }
            }.frame(width: 160, alignment: .leading)
            content()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }

    private func pickFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { completion(url.path) }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add MimirToolUI/Views/Settings/
git commit -m "feat: Settings view with environment management and app preferences"
```

---

## Task 13: Wire Up & Final Polish

**Files:**
- Modify: `MimirToolUI/MimirToolUIApp.swift`
- Modify: `MimirToolUI/Info.plist` (add entitlements for network + file access)

- [ ] **Step 1: Add App Sandbox entitlements**

  In Xcode → Target → Signing & Capabilities → App Sandbox:
  - ✓ Outgoing Connections (Client)
  - ✓ User Selected File (Read/Write)

- [ ] **Step 2: Pass AppSettings from @AppStorage into MimirtoolRunner**

  Update `RulesView`, `AlertmanagerView`, `RemoteReadView` to read `@AppStorage("mimirtoolPath")` and pass it when creating `MimirtoolRunner`:

```swift
// In each view's init, replace:
_vm = StateObject(wrappedValue: RulesViewModel(runner: MimirtoolRunner(), environment: environment))

// With:
@AppStorage("mimirtoolPath") private var mimirtoolPath: String = ""

// And in body or via @StateObject init workaround, construct with settings:
let settings = AppSettings(mimirtoolPath: mimirtoolPath.isEmpty ? nil : mimirtoolPath)
let runner = MimirtoolRunner(settings: settings)
```

  Since `@AppStorage` can't be read in `init`, use a factory approach — add to each ViewModel:

```swift
// Add to MimirtoolRunner
static func fromAppStorage() -> MimirtoolRunner {
    let path = UserDefaults.standard.string(forKey: "mimirtoolPath")
    return MimirtoolRunner(settings: AppSettings(mimirtoolPath: path))
}
```

  Then use `MimirtoolRunner.fromAppStorage()` in all view inits.

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep -E "PASSED|FAILED|passed|failed|error:"
```

  Expected: all tests pass, no compile errors.

- [ ] **Step 4: Build the app**

```bash
xcodebuild build -scheme MimirToolUI -destination 'platform=macOS' 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
```

  Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: wire up app settings to runners, add sandbox entitlements"
```

---

## Self-Review Checklist

- [x] **Environments (add/edit/delete/switch)** → Task 4 (EnvironmentStore) + Task 12 (SettingsView + forms)
- [x] **Environment quick-switch popover** → Task 8 (EnvironmentSwitcherPopover)
- [x] **Rules: list, upload, inline edit, delete** → Task 7 (RulesViewModel) + Task 9 (RulesView + RuleEditorSheet)
- [x] **Alertmanager: view/edit/upload/push/delete** → Task 6 (AlertmanagerViewModel) + Task 10 (AlertmanagerView)
- [x] **Alerts: list with filter chips, label pills, duration** → Task 5 (AlertsService) + Task 6 (AlertsViewModel) + Task 11 (AlertsView)
- [x] **Remote Read: query form, results table, CSV export** → Task 6 (RemoteReadViewModel) + Task 11 (RemoteReadView)
- [x] **Settings: binary path, TLS, timeout, retries, log level, verbose** → Task 12 (SettingsView)
- [x] **mimirtool binary auto-detect** → Task 3 (MimirtoolRunner.binaryCandidates)
- [x] **WailBrew dark style** → Color(hex:) throughout, card shadows, sidebar structure
- [x] **Firing alert count badge in sidebar** → SidebarView passes badge to Alerts nav item
- [x] **Error banners** → ErrorBannerView used in all 4 content views
- [x] **Status bar in each page** → StatusBarView used in Rules, Alertmanager, Alerts, Remote Read
