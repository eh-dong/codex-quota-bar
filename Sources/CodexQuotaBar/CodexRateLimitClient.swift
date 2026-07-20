import Foundation

final class CodexRateLimitClient {
    private let codexPath: String

    init(codexPath: String = CodexRateLimitClient.findCodexPath()) {
        self.codexPath = codexPath
    }

    func fetchRateLimits() async throws -> RateLimitsSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    continuation.resume(returning: try self.fetchRateLimitsSync())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchRateLimitsSync() throws -> RateLimitsSnapshot {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.environment = CodexProcessEnvironment.make(base: ProcessInfo.processInfo.environment)

        let input = Pipe()
        let output = Pipe()
        let errorOutput = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput

        try process.run()

        let lock = NSLock()
        let completed = DispatchSemaphore(value: 0)
        var buffer = Data()
        var targetMessage: [String: Any]?
        var parseError: Error?

        output.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }

            lock.lock()
            defer { lock.unlock() }

            buffer.append(chunk)
            do {
                if let message = try CodexRateLimitParser.parseTargetMessage(from: buffer) {
                    targetMessage = message
                    completed.signal()
                }
            } catch {
                parseError = error
                completed.signal()
            }
        }

        let requests = [
            #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"codex_quota_bar","title":"CodexQuotaBar","version":"0.1.0"},"capabilities":{"experimentalApi":true}}}"#,
            #"{"method":"initialized","params":{}}"#,
            #"{"method":"account/rateLimits/read","id":2,"params":null}"#
        ]
        input.fileHandleForWriting.write(requests.joined(separator: "\n").data(using: .utf8)!)
        input.fileHandleForWriting.write("\n".data(using: .utf8)!)

        if completed.wait(timeout: .now() + 8) == .success {
            output.fileHandleForReading.readabilityHandler = nil
            process.terminate()

            if let parseError {
                throw parseError
            }
            if let targetMessage {
                return try CodexRateLimitParser.decodeRateLimits(from: targetMessage)
            }
        }

        output.fileHandleForReading.readabilityHandler = nil
        process.terminate()
        let stderr = String(data: errorOutput.fileHandleForReading.availableData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        throw QuotaBarError.timeout(errorMessage(from: stderr))
    }

    private func errorMessage(from stderr: String?) -> String {
        guard let stderr, !stderr.isEmpty else {
            return "Codex app-server timed out"
        }

        if stderr.contains("env: node: No such file or directory") {
            return "Codex CLI depends on node; Homebrew path is missing from the app environment. Original error: \(stderr)"
        }

        return stderr
    }

    private static func findCodexPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return "/opt/homebrew/bin/codex"
    }
}

enum CodexProcessEnvironment {
    private static let requiredPathEntries = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    static func make(base: [String: String]) -> [String: String] {
        var environment = base
        environment["PATH"] = mergedPath(existing: base["PATH"])
        return environment
    }

    private static func mergedPath(existing: String?) -> String {
        var seen = Set<String>()
        var entries: [String] = []

        func append(_ entry: String) {
            guard !entry.isEmpty, !seen.contains(entry) else { return }
            seen.insert(entry)
            entries.append(entry)
        }

        requiredPathEntries.forEach(append)
        existing?.split(separator: ":").map(String.init).forEach(append)

        return entries.joined(separator: ":")
    }
}

enum CodexRateLimitParser {
    static func parseTargetMessage(from data: Data) throws -> [String: Any]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  json["id"] as? Int == 2 else {
                continue
            }
            return json
        }
        return nil
    }

    static func decodeRateLimits(from message: [String: Any]) throws -> RateLimitsSnapshot {
        if let error = message["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw QuotaBarError.appServer(message)
        }

        guard let result = message["result"] as? [String: Any] else {
            throw QuotaBarError.invalidResponse
        }

        let codex = decodeLimit(result["rateLimits"] as? [String: Any])
        var spark: RateLimitSnapshot?
        if let limitsById = result["rateLimitsByLimitId"] as? [String: Any] {
            for (key, value) in limitsById where key != "codex" {
                spark = decodeLimit(value as? [String: Any])
                if spark != nil { break }
            }
        }

        let resetCreditsAvailableCount = (result["rateLimitResetCredits"] as? [String: Any])?["availableCount"] as? Int
        return RateLimitsSnapshot(
            codex: codex,
            spark: spark,
            resetCreditsAvailableCount: resetCreditsAvailableCount
        )
    }

    private static func decodeLimit(_ value: [String: Any]?) -> RateLimitSnapshot? {
        guard let value else { return nil }
        return RateLimitSnapshot(
            limitId: value["limitId"] as? String,
            limitName: value["limitName"] as? String,
            primary: decodeWindow(value["primary"] as? [String: Any]),
            secondary: decodeWindow(value["secondary"] as? [String: Any]),
            credits: decodeCredits(value["credits"] as? [String: Any])
        )
    }

    private static func decodeWindow(_ value: [String: Any]?) -> RateLimitWindow? {
        guard let value, let usedPercent = value["usedPercent"] as? Int else { return nil }
        let resetsAtValue = value["resetsAt"] as? NSNumber
        let resetsAt = resetsAtValue.map { Date(timeIntervalSince1970: $0.doubleValue) }
        return RateLimitWindow(
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            windowDurationMins: value["windowDurationMins"] as? Int
        )
    }

    private static func decodeCredits(_ value: [String: Any]?) -> CreditsSnapshot? {
        guard let value else { return nil }
        return CreditsSnapshot(balance: value["balance"] as? String)
    }
}
