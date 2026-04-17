import Foundation

struct AppSettings: Codable {
    var mimirtoolPath: String?
    var logLevel: String
    var verboseOutput: Bool

    init(mimirtoolPath: String? = nil, logLevel: String = "info", verboseOutput: Bool = false) {
        self.mimirtoolPath = mimirtoolPath
        self.logLevel = logLevel
        self.verboseOutput = verboseOutput
    }
}
