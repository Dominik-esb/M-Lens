import Foundation

struct MimirAlert: Codable, Identifiable {
    var id: String { labels["alertname"] ?? UUID().uuidString }
    let labels: [String: String]
    let state: AlertState
    let activeAt: String?

    enum AlertState: String, Codable {
        case firing, pending, inactive
    }

    enum CodingKeys: String, CodingKey {
        case labels, state, activeAt
    }
}

struct AlertsAPIResponse: Codable {
    let status: String
    let data: [MimirAlert]
}
