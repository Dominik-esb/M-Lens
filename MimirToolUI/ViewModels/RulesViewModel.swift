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

    /// Injectable for testing: returns the URL of the temp directory where
    /// `mimirtool rules print --output-dir` writes per-namespace YAML files.
    var tmpDirProvider: () -> URL = {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MimirToolUI-rules-\(Int(Date().timeIntervalSince1970))")
    }

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
        let tmpDir = tmpDirProvider()
        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            _ = try await runner.run(
                ["rules", "print", "--output-dir", tmpDir.path],
                environment: environment
            )
            namespaces = try parseRulesDirectory(tmpDir)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchRuleGroupYAML(namespace: String, group: String) async throws -> String {
        try await runner.run(["rules", "get", namespace, group], environment: environment)
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
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MimirToolUI-rules")
        let file = dir.appendingPathComponent("rules-push.yaml")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try yamlContent.write(to: file, atomically: true, encoding: .utf8)
            _ = try await runner.run(["rules", "load", file.path], environment: environment)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private parsing

    private func parseRulesDirectory(_ dir: URL) throws -> [RuleNamespace] {
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { ["yaml", "yml"].contains($0.pathExtension) }
        return files.compactMap { file -> RuleNamespace? in
            let ns = file.deletingPathExtension().lastPathComponent
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let groups = parseGroupsFromYAML(content, namespace: ns)
            guard !groups.isEmpty else { return nil }
            return RuleNamespace(name: ns, groups: groups)
        }.sorted { $0.name < $1.name }
    }

    /// Parse group/rule metadata from mimirtool rules list YAML output.
    /// Handles the standard Prometheus rules YAML format written by mimirtool.
    private func parseGroupsFromYAML(_ yaml: String, namespace: String) -> [RuleGroup] {
        var groups: [RuleGroup] = []
        var currentName = ""
        var currentRules: [Rule] = []
        for line in yaml.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("- name:") {
                if !currentName.isEmpty {
                    groups.append(RuleGroup(namespace: namespace, name: currentName, rules: currentRules))
                }
                currentName = String(t.dropFirst("- name:".count)).trimmingCharacters(in: .whitespaces)
                currentRules = []
            } else if t.hasPrefix("- alert:") {
                let name = String(t.dropFirst("- alert:".count)).trimmingCharacters(in: .whitespaces)
                currentRules.append(Rule(group: currentName, ruleName: name, type: .alerting, yaml: "", namespace: namespace))
            } else if t.hasPrefix("- record:") {
                let name = String(t.dropFirst("- record:".count)).trimmingCharacters(in: .whitespaces)
                currentRules.append(Rule(group: currentName, ruleName: name, type: .recording, yaml: "", namespace: namespace))
            }
        }
        if !currentName.isEmpty {
            groups.append(RuleGroup(namespace: namespace, name: currentName, rules: currentRules))
        }
        return groups.sorted { $0.name < $1.name }
    }
}
