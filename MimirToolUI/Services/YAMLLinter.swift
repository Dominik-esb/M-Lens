import Foundation

struct YAMLDiagnostic: Identifiable, Sendable {
    let id = UUID()
    let line: Int       // 1-based; 0 = file-level / unknown
    let message: String
}

/// Validates YAML using Ruby's Psych parser (always available on macOS).
enum YAMLLinter {
    static func lint(_ yaml: String) async -> [YAMLDiagnostic] {
        let copy = yaml
        return await Task.detached(priority: .utility) { runLint(copy) }.value
    }

    private static func runLint(_ yaml: String) -> [YAMLDiagnostic] {
        let script = """
require 'yaml'
require 'json'
begin
  YAML.safe_load($stdin.read, permitted_classes: [], permitted_symbols: [], aliases: true)
  puts '[]'
rescue Psych::SyntaxError => e
  line = (e.respond_to?(:line) ? e.line.to_i : 0)
  msg  = [e.problem, e.context].compact.reject(&:empty?).join(' — ')
  msg  = e.message.split("\\n").first || 'YAML syntax error' if msg.empty?
  puts [{line: line, message: msg}].to_json
rescue => e
  puts [{line: 0, message: e.message.split("\\n").first.to_s}].to_json
end
"""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        proc.arguments = ["-e", script]

        let stdin  = Pipe(), stdout = Pipe(), stderr = Pipe()
        proc.standardInput  = stdin
        proc.standardOutput = stdout
        proc.standardError  = stderr

        do {
            try proc.run()
            stdin.fileHandleForWriting.write(Data(yaml.utf8))
            stdin.fileHandleForWriting.closeFile()
            proc.waitUntilExit()

            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            struct Row: Decodable { let line: Int; let message: String }
            let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
            return rows.map { YAMLDiagnostic(line: $0.line, message: $0.message) }
        } catch {
            return []
        }
    }
}
