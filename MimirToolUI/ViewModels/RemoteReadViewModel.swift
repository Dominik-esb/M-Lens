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

    // MARK: - Metric Browser
    @Published var availableMetrics: [String] = []
    @Published var isFetchingMetrics = false
    @Published var metricSearchText = ""

    var filteredMetrics: [String] {
        if metricSearchText.isEmpty { return availableMetrics }
        return availableMetrics.filter { $0.localizedCaseInsensitiveContains(metricSearchText) }
    }

    private let runner: MimirtoolRunning
    private let environment: MimirEnvironment

    init(runner: MimirtoolRunning, environment: MimirEnvironment) {
        self.runner = runner
        self.environment = environment
    }

    // MARK: - Time Range Label

    var timeRangeLabel: String {
        let diff = toDate.timeIntervalSince(fromDate)
        switch diff {
        case ..<(60 * 16): return "Last 15m"
        case ..<(3601): return "Last 1h"
        case ..<(6 * 3601): return "Last 6h"
        case ..<(24 * 3601): return "Last 24h"
        case ..<(7 * 24 * 3601 + 1): return "Last 7d"
        default:
            let fmt = DateFormatter()
            fmt.dateFormat = "MM/dd HH:mm"
            return "\(fmt.string(from: fromDate)) → \(fmt.string(from: toDate))"
        }
    }

    // MARK: - Metric Loading

    @Published var metricsError: String?

    func loadMetrics() async {
        isFetchingMetrics = true
        metricsError = nil
        do {
            availableMetrics = try await fetchMetricNames()
        } catch {
            metricsError = error.localizedDescription
        }
        isFetchingMetrics = false
    }

    private func fetchMetricNames() async throws -> [String] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let to = Date()
        // Use a 1-hour window — 5 minutes is often too short to find any series
        let from = Calendar.current.date(byAdding: .hour, value: -1, to: to) ?? to
        let output = try await runner.run([
            "remote-read", "dump",
            "--selector", "{}",
            "--from", formatter.string(from: from),
            "--to", formatter.string(from: to)
        ], environment: environment)
        var names = Set<String>()
        let pattern = try? NSRegularExpression(pattern: #"__name__="([^"]+)""#)
        for line in output.components(separatedBy: "\n") {
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = pattern?.firstMatch(in: line, range: range) {
                names.insert(ns.substring(with: match.range(at: 1)))
            }
        }
        return names.sorted()
    }

    // MARK: - Query

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
