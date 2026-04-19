import Foundation
import Combine

@MainActor
final class RulesViewModel: ObservableObject {
    @Published var namespaces: [RuleNamespace] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var activityMessage: ActivityMessage?

    private let runner: MimirtoolRunning
    private let environment: MimirEnvironment
    private var toastTask: Task<Void, Never>?

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

    // MARK: - Delete (single rule)

    /// Deletes only the named rule from its group. If it's the last rule in the
    /// group the whole group is removed; otherwise the group is re-uploaded minus
    /// that rule using Ruby/Psych (same runtime used for linting).
    func deleteRule(namespace: String, group: String, ruleName: String) async {
        errorMessage = nil
        do {
            let groupYAML = try await runner.run(["rules", "get", namespace, group], environment: environment)
            if let modifiedYAML = try removeRuleFromYAML(groupYAML, ruleName: ruleName) {
                // Re-upload the group with the rule removed
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MimirToolUI-rules")
                let file = dir.appendingPathComponent("rules-delete-patch.yaml")
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try modifiedYAML.write(to: file, atomically: true, encoding: .utf8)
                _ = try await runner.run(["rules", "load", file.path], environment: environment)
            } else {
                // No rules left in the group — delete it entirely
                _ = try await runner.run(["rules", "delete", namespace, group], environment: environment)
            }
            await load()
            showToast("Deleted rule \"\(ruleName)\"", isError: false)
        } catch {
            errorMessage = error.localizedDescription
            showToast("Delete failed: \(error.localizedDescription)", isError: true)
        }
    }

    func deleteGroup(namespace: String, group: String) async {
        errorMessage = nil
        do {
            _ = try await runner.run(["rules", "delete", namespace, group], environment: environment)
            await load()
            showToast("Deleted group \"\(group)\"", isError: false)
        } catch {
            errorMessage = error.localizedDescription
            showToast("Delete failed: \(error.localizedDescription)", isError: true)
        }
    }

    func deleteNamespace(_ namespace: String) async {
        errorMessage = nil
        do {
            _ = try await runner.run(["rules", "delete", namespace], environment: environment)
            await load()
            showToast("Deleted namespace \"\(namespace)\"", isError: false)
        } catch {
            errorMessage = error.localizedDescription
            showToast("Delete failed: \(error.localizedDescription)", isError: true)
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
            showToast("Rules uploaded successfully", isError: false)
        } catch {
            errorMessage = error.localizedDescription
            showToast("Upload failed: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Toast

    private func showToast(_ text: String, isError: Bool) {
        toastTask?.cancel()
        activityMessage = ActivityMessage(text: text, isError: isError)
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            activityMessage = nil
        }
    }

    // MARK: - YAML rule removal via Ruby/Psych

    /// Returns modified YAML with the named rule removed, or nil if no rules remain.
    private func removeRuleFromYAML(_ yaml: String, ruleName: String) throws -> String? {
        let escapedName = ruleName.replacingOccurrences(of: "'", with: "\\'")
        let script = """
        require 'yaml'
        config = YAML.safe_load(STDIN.read, permitted_classes: [])
        config['groups']&.each do |g|
          g['rules']&.reject! { |r| (r['alert'] || r['record']).to_s == '\(escapedName)' }
        end
        config['groups']&.reject! { |g| g['rules'].nil? || g['rules'].empty? }
        if config['groups'].nil? || config['groups'].empty?
          puts '__EMPTY__'
        else
          print YAML.dump(config)
        end
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        process.arguments = ["-e", script]

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        stdin.fileHandleForWriting.write(yaml.data(using: .utf8) ?? Data())
        stdin.fileHandleForWriting.closeFile()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: outData, encoding: .utf8) ?? ""
        if output.contains("__EMPTY__") { return nil }
        return output.isEmpty ? nil : output
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
