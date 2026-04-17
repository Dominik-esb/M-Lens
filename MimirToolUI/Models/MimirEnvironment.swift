import Foundation

struct MimirEnvironment: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var orgID: String?
    var extraHeaders: [String: String]
    var tlsSkipVerify: Bool
    var caCertPath: String?
    var timeout: String
    var retries: Int

    init(id: UUID = UUID(), name: String, url: String, orgID: String? = nil,
         extraHeaders: [String: String] = [:], tlsSkipVerify: Bool = false,
         caCertPath: String? = nil, timeout: String = "30s", retries: Int = 3) {
        self.id = id; self.name = name; self.url = url; self.orgID = orgID
        self.extraHeaders = extraHeaders; self.tlsSkipVerify = tlsSkipVerify
        self.caCertPath = caCertPath; self.timeout = timeout; self.retries = retries
    }
}
