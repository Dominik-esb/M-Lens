import Foundation

struct RemoteReadResult: Identifiable {
    let id = UUID()
    let metricName: String
    let labels: [String: String]
    let latestValue: String
    let timestamp: String
}
