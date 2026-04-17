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

    func runQuery() async {
        guard !selector.isEmpty else {
            errorMessage = "Selector is required"
            return
        }
        isLoading = true
        errorMessage = nil
        let start = Date()
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let output = try await runner.run([
                "remote-read", "dump",
                "--selector", selector,
                "--from", formatter.string(from: fromDate),
                "--to", formatter.string(from: toDate)
            ], environment: environment)
            results = parseDumpOutput(output)
            queryDuration = String(format: "%.0fms", Date().timeIntervalSince(start) * 1000)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func exportCSV(to url: URL) throws {
        var csv = "metric,labels,value,timestamp\n"
        for r in results {
            let labels = r.labels.sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ",")
            csv += "\(r.metricName),\"\(labels)\",\(r.latestValue),\(r.timestamp)\n"
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Parse `mimirtool remote-read dump` stdout.
    /// Each line: `{__name__="foo",label="val"} value timestamp_ms`
    /// We deduplicate per series, keeping the last (most recent) sample.
    private func parseDumpOutput(_ output: String) -> [RemoteReadResult] {
        guard let regex = try? NSRegularExpression(pattern: #"(\w+)="([^"]*)""#) else { return [] }
        var latest: [String: RemoteReadResult] = [:]

        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("{"), let closeBrace = t.firstIndex(of: "}") else { continue }

            let labelsStr = String(t[t.index(after: t.startIndex)..<closeBrace])
            let rest = String(t[t.index(after: closeBrace)...]).trimmingCharacters(in: .whitespaces)
            let parts = rest.components(separatedBy: " ")
            guard parts.count >= 2 else { continue }

            let value = parts[0]
            // Skip stale NaN values
            if value == "NaN" || value == "nan" { continue }

            let tsStr = parts[1]
            let tsFormatted: String
            if let tsMs = Double(tsStr) {
                let date = Date(timeIntervalSince1970: tsMs / 1000)
                let fmt = DateFormatter()
                fmt.dateFormat = "HH:mm:ss"
                tsFormatted = fmt.string(from: date)
            } else {
                tsFormatted = tsStr
            }

            var labels: [String: String] = [:]
            var name = "unknown"
            let nsLabels = labelsStr as NSString
            let matches = regex.matches(in: labelsStr, range: NSRange(labelsStr.startIndex..., in: labelsStr))
            for match in matches {
                let k = nsLabels.substring(with: match.range(at: 1))
                let v = nsLabels.substring(with: match.range(at: 2))
                if k == "__name__" { name = v } else { labels[k] = v }
            }

            latest[labelsStr] = RemoteReadResult(metricName: name, labels: labels,
                                                 latestValue: value, timestamp: tsFormatted)
        }
        return latest.values.sorted { $0.metricName < $1.metricName }
    }
}
