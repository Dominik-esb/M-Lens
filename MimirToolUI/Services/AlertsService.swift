import Foundation

protocol AlertsFetching: Sendable {
    func fetch(for env: MimirEnvironment) async throws -> [MimirAlert]
}

// Decodable wrapper matching Prometheus /api/v1/alerts response shape:
// {"status":"success","data":{"alerts":[...]}}
private struct PrometheusAlertsEnvelope: Decodable {
    struct DataWrapper: Decodable {
        let alerts: [MimirAlert]
    }
    let status: String
    let data: DataWrapper
}

final class AlertsService: AlertsFetching {

    func buildRequest(for env: MimirEnvironment) throws -> URLRequest {
        guard let base = URL(string: env.url),
              let scheme = base.scheme,
              scheme == "http" || scheme == "https" else {
            throw URLError(.badURL)
        }
        let url = base.appendingPathComponent("prometheus/api/v1/alerts")
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        req.httpMethod = "GET"
        if let orgID = env.orgID, !orgID.isEmpty {
            req.setValue(orgID, forHTTPHeaderField: "X-Scope-OrgID")
        }
        for (key, value) in env.extraHeaders {
            req.setValue(value, forHTTPHeaderField: key)
        }
        return req
    }

    func parse(data: Data) throws -> [MimirAlert] {
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(PrometheusAlertsEnvelope.self, from: data)
        return envelope.data.alerts
    }

    func fetch(for env: MimirEnvironment) async throws -> [MimirAlert] {
        let request = try buildRequest(for: env)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AlertsServiceError.httpError(statusCode: http.statusCode, body: body)
        }
        return try parse(data: data)
    }
}

enum AlertsServiceError: LocalizedError, Sendable {
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}
