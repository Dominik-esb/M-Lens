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
        let outFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("mimir-remote-read-\(Int(Date().timeIntervalSince1970)).json")
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            _ = try await runner.run([
                "remote-read", "export",
                "--selector", selector,
                "--from", formatter.string(from: fromDate),
                "--to", formatter.string(from: toDate),
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
            let labels = r.labels.sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ",")
            csv += "\(r.metricName),\"\(labels)\",\(r.latestValue),\(r.timestamp)\n"
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Parse JSON Lines output from mimirtool remote-read export.
    /// Each line: {"metric":{"__name__":"foo","label":"val"},"values":[[timestamp,"value"],...]}
    private func parseResults(from url: URL) throws -> [RemoteReadResult] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var results: [RemoteReadResult] = []
        for line in content.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let metric = obj["metric"] as? [String: String],
                  let values = obj["values"] as? [[Any]],
                  let last = values.last,
                  last.count == 2 else { continue }
            let name = metric["__name__"] ?? "unknown"
            let labels = metric.filter { $0.key != "__name__" }
            let val = last[1] as? String ?? "\(last[1])"
            let ts = "\(last[0])"
            results.append(RemoteReadResult(metricName: name, labels: labels,
                                            latestValue: val, timestamp: ts))
        }
        return results
    }
}
