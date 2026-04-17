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
            let output = try await runner.run(["rules", "list"], environment: environment)
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

    /// Parse mimirtool rules list stdout.
    /// Expected format per line:
    ///   "Namespace: <name>"
    ///   "  Group: <group>"
    ///   "    Rule: <rulename> (<alerting|recording>)"
    private func parseRulesOutput(_ output: String) -> [RuleNamespace] {
        var namespaces: [String: [String: [Rule]]] = [:]
        var currentNS = ""
        var currentGroup = ""
        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Namespace:") {
                currentNS = t.replacingOccurrences(of: "Namespace:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if namespaces[currentNS] == nil { namespaces[currentNS] = [:] }
            } else if t.hasPrefix("Group:") {
                currentGroup = t.replacingOccurrences(of: "Group:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if namespaces[currentNS]?[currentGroup] == nil {
                    namespaces[currentNS]?[currentGroup] = []
                }
            } else if t.hasPrefix("Rule:") {
                let rest = t.replacingOccurrences(of: "Rule:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let isRecording = rest.contains("(recording)")
                let name = rest
                    .replacingOccurrences(of: "(alerting)", with: "")
                    .replacingOccurrences(of: "(recording)", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let rule = Rule(group: currentGroup, ruleName: name,
                                type: isRecording ? .recording : .alerting,
                                yaml: "", namespace: currentNS)
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
