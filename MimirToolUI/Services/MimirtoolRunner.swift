import Foundation

// Protocol enables mocking in ViewModel tests
protocol MimirtoolRunning: Sendable {
    func run(_ args: [String], environment: MimirEnvironment) async throws -> String
    func resolvedBinaryPath(override: String?) -> String?
}

enum MimirtoolError: LocalizedError, Sendable {
    case binaryNotFound
    case executionFailed(exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "mimirtool binary not found. Please set the path in Settings."
        case .executionFailed(let code, let stderr):
            return "mimirtool exited \(code): \(stderr)"
        }
    }
}

final class MimirtoolRunner: MimirtoolRunning {
    private let settings: AppSettings

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    static func fromUserDefaults() -> MimirtoolRunner {
        let path = UserDefaults.standard.string(forKey: "mimirtoolPath")
        return MimirtoolRunner(settings: AppSettings(mimirtoolPath: path.flatMap { $0.isEmpty ? nil : $0 }))
    }

    func binaryCandidates() -> [String] {
        [
            "/opt/homebrew/bin/mimirtool",
            "/usr/local/bin/mimirtool",
            "/usr/bin/mimirtool",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/.local/bin/mimirtool"
        ]
    }

    func resolvedBinaryPath(override: String? = nil) -> String? {
        if let override, !override.isEmpty, FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        if let path = settings.mimirtoolPath, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return binaryCandidates().first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func baseArgs(for env: MimirEnvironment) -> [String] {
        var args: [String] = ["--address=\(env.url)"]
        if let orgID = env.orgID, !orgID.isEmpty {
            args.append("--id=\(orgID)")
        }
        if env.tlsSkipVerify {
            args.append("--tls.insecure-skip-verify")
        }
        if let ca = env.caCertPath, !ca.isEmpty {
            args.append("--tls.ca-path=\(ca)")
        }
        for (key, value) in env.extraHeaders.sorted(by: { $0.key < $1.key }) {
            args.append("--extra-headers=\(key):\(value)")
        }
        return args
    }

    func run(_ args: [String], environment env: MimirEnvironment) async throws -> String {
        guard let binary = resolvedBinaryPath() else {
            throw MimirtoolError.binaryNotFound
        }
        let allArgs = baseArgs(for: env) + args

        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = allArgs

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return out
            } else {
                throw MimirtoolError.executionFailed(exitCode: process.terminationStatus, stderr: err)
            }
        }.value
    }
}
