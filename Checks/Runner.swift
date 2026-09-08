import Foundation

private func check(_ condition: Bool, _ label: String) {
    guard condition else { fatalError(label) }
    print("PASS: \(label)")
}
private final class SequenceReader: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    let usage: Usage
    init(_ usage: Usage) { self.usage = usage }
    func read(_ path: String?) throws -> Usage {
        lock.lock(); calls += 1; let call = calls; lock.unlock()
        Thread.sleep(forTimeInterval: 0.05)
        if call == 2 { throw UsageError.offline }
        return usage
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
}
@main struct Checks {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let scratch = fm.temporaryDirectory.appendingPathComponent("allowance-checks-" + UUID().uuidString)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scratch) }
        let fixture = #"{"rateLimits":{"limitId":"legacy","primary":null,"secondary":null},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":9,"windowDurationMins":10080,"resetsAt":null},"secondary":null}}}"#
        let usage = try JSONDecoder().decode(Usage.self, from: Data(fixture.utf8))
        check(Window(usedPercent: 110, windowDurationMins: nil, resetsAt: nil).remaining == 0, "Over-limit clamps to zero")
        check(Window(usedPercent: -5, windowDurationMins: nil, resetsAt: nil).remaining == 100, "Remaining caps at 100")
        check(usage.buckets.first?.primary?.title == "Weekly", "Duration controls label")
        check(usage.buckets.count == 1 && usage.buckets.first?.primary?.remaining == 91, "Map takes precedence")
        check(usage.buckets.first?.secondary == nil, "Missing window stays unavailable")
        let legacy = Data(#"{"rateLimits":{"limitId":"codex","primary":null,"secondary":null},"rateLimitsByLimitId":null}"#.utf8)
        check(try JSONDecoder().decode(Usage.self, from: legacy).buckets.count == 1, "Legacy fallback")

        func server(_ response: String?, notification: Bool = false) throws -> String {
            let url = scratch.appendingPathComponent(UUID().uuidString)
            // JSON fixtures are test-only; never used in the app.
            let quoted = (response ?? "").replacingOccurrences(of: "'", with: "'\\''")
            let body = """
            #!/bin/sh
            IFS= read -r request
            case "$request" in *initialize*) ;; *) exit 8;; esac
            printf '%s\\n' '{"id":1,"result":{}}'
            IFS= read -r request
            case "$request" in *initialized*) ;; *) exit 9;; esac
            IFS= read -r request
            case "$request" in *account/rateLimits/read*) ;; *) exit 10;; esac
            \(notification ? "printf '%s\\n' '{\"method\":\"notice\",\"params\":{}}'" : "")
            \(response == nil ? "IFS= read -r request" : "printf '%s\\n' '" + quoted + "'")
            """
            try body.write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            return url.path
        }
        let success = try server("{\"id\":2,\"result\":\(fixture)}", notification: true)
        check(try UsageClient.read(executable: success).buckets.first?.primary?.remaining == 91, "Handshake, notification, and response transport")
        for (response, expected, label) in [
            (#"{"id":2,"error":{"message":"401 Unauthorized"}}"#, UsageError.signedOut, "Expired sign-in"),
            (#"{"id":2,"error":{"message":"network connection unavailable"}}"#, .offline, "Offline response"),
            ("not-json", .malformed, "Malformed JSON"),
            (#"{"id":2,"result":{"unrecognized":true}}"#, .malformed, "Unexpected response schema")
        ] {
            do { _ = try UsageClient.read(executable: server(response)); fatalError(label) }
            catch { check(error as? UsageError == expected, label) }
        }
        let started = Date()
        do { _ = try UsageClient.read(executable: server(nil), timeout: 0.15); fatalError("Timeout") }
        catch { check(error as? UsageError == .timedOut && Date().timeIntervalSince(started) < 2, "Timeout returns promptly and reaps child") }
        check(try CLIResolver.resolve(override: success) == success, "Explicit executable selection")
        do { _ = try CLIResolver.resolve(override: scratch.path); fatalError("Directory accepted") }
        catch { check(error as? UsageError == .invalidPath, "Reject directory as executable") }
        do { _ = try CLIResolver.resolve(override: scratch.path + "/missing"); fatalError("Missing executable accepted") }
        catch { check(error as? UsageError == .invalidPath, "Deleted executable reports setup error") }

        let suite = "allowance-tests-" + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let sequence = SequenceReader(usage)
        let model = Model(preferences: preferences, reader: { try sequence.read($0) })
        func settle() async throws {
            for _ in 0..<200 {
                if !model.loading { return }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            fatalError("Model did not settle")
        }
        model.start(); model.start(); model.refresh()
        try await settle()
        check(sequence.count == 1 && model.usage != nil, "One startup timer and no concurrent refreshes")
        let timestamp = model.updated
        model.refresh(); try await settle()
        check(model.usage != nil && model.updated == timestamp && model.error != nil, "Failure preserves and marks last successful reading")
        model.refresh(); try await settle()
        check(model.error == nil && model.updated != nil && sequence.count == 3, "Recovery clears stale error")
        model.refreshIfStale(); check(sequence.count == 3, "Opening a fresh panel does not fetch again")
        model.stop()
        if ProcessInfo.processInfo.environment["ALLOWANCE_LIVE_TEST"] == "1" {
            check(try !UsageClient.read().buckets.isEmpty, "Live account read")
        }
    }
}
