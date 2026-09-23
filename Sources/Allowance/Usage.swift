import Foundation
import Darwin
enum CapacityLevel {
    case normal, warning, critical
}
struct Window: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
    var remaining: Double { min(100, max(0, 100 - usedPercent)) }
    var capacityLevel: CapacityLevel {
        if remaining <= 10 { return .critical }
        if remaining <= 20 { return .warning }
        return .normal
    }
    var title: String {
        guard let m = windowDurationMins else { return "Allowance window" }
        if m == 10080 { return "Weekly" }
        if m % 1440 == 0 { return "\(m / 1440)-day" }
        if m % 60 == 0 { return "\(m / 60)-hour" }
        return "\(m)-minute"
    }
}
struct Bucket: Decodable {
    let limitId: String?
    let limitName: String?
    let primary: Window?
    let secondary: Window?
    var title: String { limitName ?? (limitId == "codex" ? "Codex" : limitId ?? "Account") }
}
struct Usage: Decodable {
    let rateLimits: Bucket?
    let rateLimitsByLimitId: [String: Bucket]?
    var buckets: [Bucket] {
        if let map = rateLimitsByLimitId, !map.isEmpty { return map.keys.sorted().compactMap { map[$0] } }
        return rateLimits.map { [$0] } ?? []
    }
}
enum UsageError: LocalizedError, Equatable {
    case missing, invalidPath, signedOut, offline, timedOut, malformed, unavailable
    var errorDescription: String? {
        switch self {
        case .missing: return "Codex CLI was not found. Choose its executable in Settings, or install Codex and sign in."
        case .invalidPath: return "The selected Codex executable is no longer available. Choose it again in Settings."
        case .signedOut: return "Codex needs you to sign in again. Run codex login in Terminal, then refresh."
        case .offline: return "Unable to reach Codex. Check your connection, then refresh."
        case .timedOut: return "Codex took too long to respond. Try refreshing."
        case .malformed: return "Codex returned an unexpected response. Check your CLI version in Settings."
        case .unavailable: return "Codex could not read account allowance. Check your sign-in and connection, then refresh."
        }
    }
    static func fromServer(_ message: String) -> UsageError {
        let message = message.lowercased()
        if ["unauthorized", "not authenticated", "not logged", "sign in", "401", "authentication", "chatgpt authentication"].contains(where: message.contains) { return .signedOut }
        if ["network", "connect", "dns", "offline", "error sending request"].contains(where: message.contains) { return .offline }
        return .unavailable
    }
}
struct CLIResolver {
    static func resolve(override: String? = nil, home: String = FileManager.default.homeDirectoryForCurrentUser.path,
                        searchPath: String = ProcessInfo.processInfo.environment["PATH"] ?? "") throws -> String {
        if let override, !override.isEmpty {
            guard valid(override) else { throw UsageError.invalidPath }
            return override
        }
        let candidates = [home + "/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
            + searchPath.split(separator: ":").filter { $0.hasPrefix("/") }.map { String($0) + "/codex" }
        guard let match = candidates.first(where: valid) else { throw UsageError.missing }
        return match
    }
    static func valid(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return path.hasPrefix("/") && FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue && FileManager.default.isExecutableFile(atPath: path)
    }
}
struct UsageClient {
    static func read(override: String? = nil) throws -> Usage {
        try read(executable: CLIResolver.resolve(override: override))
    }
    // Separate transport entry point allows local fake-server tests without account access.
    static func read(executable: String, timeout: TimeInterval = 25) throws -> Usage {
        let data = try request(executable: executable, method: "account/rateLimits/read", timeout: timeout)
        guard let usage = try? JSONDecoder().decode(Usage.self, from: data),
              usage.rateLimits != nil || usage.rateLimitsByLimitId != nil else { throw UsageError.malformed }
        return usage
    }
    /// Shared read-only transport. Callers validate their own response contract.
    static func request(executable: String, method: String, timeout: TimeInterval = 25) throws -> Data {
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
                // Only our own short-lived child is killed; no unrelated Codex processes.
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            process.waitUntilExit()
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
        }
        func send(_ object: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: object, options: .withoutEscapingSlashes)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "allowance", "version": "0.1.0"]]])
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var buffer = Data()
        var initialized = false
        while true {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw UsageError.timedOut }
            var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, Int32(min(remaining * 1000, 25_000)))
            if ready == 0 { throw UsageError.timedOut }
            if ready < 0 {
                if errno == EINTR { continue }
                throw UsageError.unavailable
            }
            var bytes = [UInt8](repeating: 0, count: 8192)
            let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
            guard count > 0 else { throw UsageError.unavailable }
            buffer.append(contentsOf: bytes.prefix(count))
            guard buffer.count <= 1_048_576 else { throw UsageError.malformed }
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                if line.isEmpty { continue }
                guard let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { throw UsageError.malformed }
                guard let id = object["id"] as? Int, id == 1 || id == 2 else { continue }
                if let error = object["error"] as? [String: Any] {
                    throw UsageError.fromServer(error["message"] as? String ?? "")
                }
                if id == 1 && !initialized {
                    guard object["result"] != nil else { throw UsageError.malformed }
                    initialized = true
                    try send(["method": "initialized"])
                    try send(["id": 2, "method": method])
                } else if id == 2 && initialized {
                    guard let result = object["result"],
                          let data = try? JSONSerialization.data(withJSONObject: result) else { throw UsageError.malformed }
                    return data
                }
            }
        }
    }
}
