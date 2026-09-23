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
        let area = NSRect(x: 0, y: 25, width: 1440, height: 875)
        let size = NSSize(width: 360, height: 410)
        let point = NSPoint(x: 8, y: 892)
        check(WindowPosition.reachableTopLeft(point, size: size, area: area) == point, "Preserve reachable window position")
        check(WindowPosition.reachableTopLeft(NSPoint(x: 2500, y: -500), size: size, area: area) == NSPoint(x: 1080, y: 47), "Recover position from disconnected display")
        let leftDisplay = NSRect(x: -1280, y: 0, width: 1280, height: 720)
        check(WindowPosition.reachableTopLeft(NSPoint(x: -1200, y: 700), size: size, area: leftDisplay) == NSPoint(x: -1200, y: 700), "Preserve negative display coordinates")
        check(WindowPosition.reachableTopLeft(.zero, size: NSSize(width: 1500, height: 900), area: leftDisplay) == NSPoint(x: -1280, y: 22), "Keep oversized window title bar reachable")
        let fm = FileManager.default
        let scratch = fm.temporaryDirectory.appendingPathComponent("allowance-checks-" + UUID().uuidString)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scratch) }
        let fixture = #"{"rateLimits":{"limitId":"legacy","primary":null,"secondary":null},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":9,"windowDurationMins":10080,"resetsAt":null},"secondary":null}}}"#
        let usage = try JSONDecoder().decode(Usage.self, from: Data(fixture.utf8))
        check(Window(usedPercent: 110, windowDurationMins: nil, resetsAt: nil).remaining == 0, "Over-limit clamps to zero")
        check(Window(usedPercent: -5, windowDurationMins: nil, resetsAt: nil).remaining == 100, "Remaining caps at 100")
        func level(_ remaining: Double) -> CapacityLevel {
            Window(usedPercent: 100 - remaining, windowDurationMins: nil, resetsAt: nil).capacityLevel
        }
        check(level(20.1) == .normal && level(20) == .warning, "Warning begins at 20 percent remaining")
        check(level(10.1) == .warning && level(10) == .critical, "Critical begins at 10 percent remaining")
        check(usage.buckets.first?.primary?.title == "Weekly", "Duration controls label")
        check(usage.buckets.count == 1 && usage.buckets.first?.primary?.remaining == 91, "Map takes precedence")
        check(usage.buckets.first?.secondary == nil, "Missing window stays unavailable")
        let legacy = Data(#"{"rateLimits":{"limitId":"codex","primary":null,"secondary":null},"rateLimitsByLimitId":null}"#.utf8)
        check(try JSONDecoder().decode(Usage.self, from: legacy).buckets.count == 1, "Legacy fallback")

        func server(_ response: String?, notification: Bool = false, method: String = "account/rateLimits/read") throws -> String {
            let url = scratch.appendingPathComponent(UUID().uuidString)
            let quoted = (response ?? "").replacingOccurrences(of: "'", with: "'\\''")
            let body = """
            #!/bin/sh
            IFS= read -r request
            case "$request" in *initialize*) ;; *) exit 8;; esac
            printf '%s\\n' '{"id":1,"result":{}}'
            IFS= read -r request
            case "$request" in *initialized*) ;; *) exit 9;; esac
            IFS= read -r request
            case "$request" in *\(method)*) ;; *) exit 10;; esac
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
        let tokenFixture = #"{"summary":{"lifetimeTokens":14876244643},"dailyUsageBuckets":[{"startDate":"2026-09-17","tokens":23571621},{"startDate":"2026-09-16","tokens":0}]}"#
        let activity = try TokenActivity.decode(Data(tokenFixture.utf8))
        let now = ISO8601DateFormatter().date(from: "2026-09-17T23:59:00Z")!
        let days = activity.days(now: now, timeZone: TokenActivity.calendar.timeZone)
        let orderedDays = activity.weekOrderedDays(now: now, timeZone: TokenActivity.calendar.timeZone)
        check(orderedDays.map { TokenActivity.calendar.component(.weekday, from: $0.date) } == [1, 2, 3, 4, 5, 6, 7] && orderedDays[4].tokens == 23571621 && orderedDays[3].tokens == 0, "Rolling totals display in Sunday-to-Saturday positions")
        let chicago = TimeZone(identifier: "America/Chicago")!
        let localCalendar = TokenActivity.displayCalendar(timeZone: chicago)
        let utcFriday = ISO8601DateFormatter().date(from: "2026-09-18T00:01:00Z")!
        let localDays = activity.days(now: utcFriday, timeZone: chicago)
        check(localCalendar.component(.weekday, from: utcFriday) == 5 && localDays[6].tokens == 23571621 && localDays[5].tokens == 0, "UTC Friday remains local Thursday with service date totals preserved")
        let localSunday = ISO8601DateFormatter().date(from: "2026-09-20T05:00:00Z")!
        let beforeSunday = activity.days(now: localSunday.addingTimeInterval(-1), timeZone: chicago)
        let afterSunday = activity.days(now: localSunday, timeZone: chicago)
        check(afterSunday.first?.date == beforeSunday[1].date && afterSunday[5].date == beforeSunday[6].date && afterSunday.count == 7, "Sunday advances the rolling window one day without clearing Saturday")
        let dstMonday = ISO8601DateFormatter().date(from: "2026-03-09T12:00:00Z")!
        let dstDays = activity.days(now: dstMonday, timeZone: chicago)
        check(dstDays.map { localCalendar.component(.weekday, from: $0.date) } == [3, 4, 5, 6, 7, 1, 2] && dstDays[6].date.timeIntervalSince(dstDays[5].date) == 23 * 3600, "Calendar days remain aligned across daylight saving")
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        check(TokenActivity.displayCalendar(timeZone: tokyo).component(.weekday, from: utcFriday) == 6 && activity.days(now: utcFriday, timeZone: tokyo)[5].tokens == 23571621, "Eastern time zones keep service dates in their correct columns")
        check(days.map { TokenActivity.calendar.component(.weekday, from: $0.date) } == [6, 7, 1, 2, 3, 4, 5] && days[6].tokens == 23571621, "Rolling UTC window ends with today's count")
        check(days[5].tokens == 0 && days[4].tokens == nil, "Explicit zero stays zero; missing dates stay unavailable")
        check(activity.days(now: now.addingTimeInterval(120), timeZone: TokenActivity.calendar.timeZone)[6].tokens == nil, "UTC midnight rolls today forward without inventing usage")
        let sunday = ISO8601DateFormatter().date(from: "2026-09-13T00:00:00Z")!
        let saturday = ISO8601DateFormatter().date(from: "2026-09-19T23:59:00Z")!
        check(activity.days(now: sunday, timeZone: TokenActivity.calendar.timeZone).first?.date == ISO8601DateFormatter().date(from: "2026-09-07T00:00:00Z") && activity.days(now: sunday, timeZone: TokenActivity.calendar.timeZone).allSatisfy { $0.tokens == nil }, "Sunday includes the previous six calendar days")
        let saturdayActivity = try TokenActivity.decode(Data(#"{"dailyUsageBuckets":[{"startDate":"2026-09-19","tokens":10}]}"#.utf8))
        check(saturdayActivity.days(now: saturday, timeZone: TokenActivity.calendar.timeZone).first?.date == sunday && saturdayActivity.days(now: saturday.addingTimeInterval(120), timeZone: TokenActivity.calendar.timeZone)[5].tokens == 10, "Sunday retains Saturday's total in the rolling window")
        let rolloverBars = saturdayActivity.weekOrderedDays(now: saturday.addingTimeInterval(120), timeZone: TokenActivity.calendar.timeZone)
        check(rolloverBars.map { TokenActivity.calendar.component(.weekday, from: $0.date) } == [1, 2, 3, 4, 5, 6, 7] && rolloverBars[6].tokens == 10 && rolloverBars[0].tokens == nil, "Sunday rollover preserves Saturday in its weekday slot")
        check(TokenActivity.compact(23571621) == "23.6M" && TokenActivity.compact(14876244643) == "14.9B", "Compact token formatting handles millions and billions")
        check(try TokenActivity.decode(Data(#"{"summary":null,"dailyUsageBuckets":null}"#.utf8)).dailyUsageBuckets == nil, "Null token metrics remain unavailable")
        check(try TokenActivity.decode(Data(#"{"summary":null,"dailyUsageBuckets":[]}"#.utf8)).days(now: now, timeZone: TokenActivity.calendar.timeZone).allSatisfy { $0.tokens == nil }, "Empty history does not invent zero days")
        for invalid in [
            #"{}"#,
            #"{"dailyUsageBuckets":[{"startDate":"2026-02-30","tokens":1}]}"#,
            #"{"dailyUsageBuckets":[{"startDate":"2026-09-17","tokens":-1}]}"#,
            #"{"dailyUsageBuckets":[{"startDate":"2026-09-17","tokens":1},{"startDate":"2026-09-17","tokens":2}]}"#
        ] {
            do { _ = try TokenActivity.decode(Data(invalid.utf8)); fatalError("Invalid token history accepted") }
            catch { check(error as? UsageError == .malformed, "Reject invalid token history") }
        }
        let tokenServer = try server("{\"id\":2,\"result\":\(tokenFixture)}", notification: true, method: "account/usage/read")
        check(try TokenActivityClient.read(executable: tokenServer).summary?.lifetimeTokens == 14876244643, "Token endpoint handshake, notification and decoding")
        do { _ = try TokenActivityClient.read(executable: server(#"{"id":2,"error":{"message":"Method not found"}}"#, method: "account/usage/read")); fatalError("Unsupported method accepted") }
        catch { check(error as? UsageError == .unavailable, "Older CLI token endpoint degrades gracefully") }
        check(try CLIResolver.resolve(override: success) == success, "Explicit executable selection")
        do { _ = try CLIResolver.resolve(override: scratch.path); fatalError("Directory accepted") }
        catch { check(error as? UsageError == .invalidPath, "Reject directory as executable") }
        do { _ = try CLIResolver.resolve(override: scratch.path + "/missing"); fatalError("Missing executable accepted") }
        catch { check(error as? UsageError == .invalidPath, "Deleted executable reports setup error") }

        let suite = "allowance-tests-" + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let sequence = SequenceReader(usage)
        let tokenSequence = SequenceReader(usage)
        let model = Model(preferences: preferences, reader: { try sequence.read($0) }, tokenReader: {
            _ = try tokenSequence.read($0)
            return activity
        })
        func settle() async throws {
            for _ in 0..<200 {
                if !model.loading && !model.tokensLoading { return }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            fatalError("Model did not settle")
        }
        model.start(); model.start(); model.refresh()
        try await settle()
        check(sequence.count == 1 && model.usage != nil, "One startup timer and no concurrent refreshes")
        let timestamp = model.updated
        let tokenTimestamp = model.tokensUpdated
        check(model.tokenActivity != nil && !model.tokensError, "Model loads token history independently")
        model.refresh(); try await settle()
        check(model.usage != nil && model.updated == timestamp && model.error != nil, "Failure preserves and marks last successful reading")
        check(model.tokenActivity != nil && model.tokensUpdated == tokenTimestamp && model.tokensError, "Token failure preserves last history and flags it stale")
        model.refresh(); try await settle()
        check(model.error == nil && model.updated != nil && sequence.count == 3, "Recovery clears stale error")
        check(!model.tokensError && tokenSequence.count == 3, "Token recovery clears stale history flag")
        let partial = Model(preferences: preferences, reader: { _ in usage }, tokenReader: { _ in throw UsageError.unavailable })
        partial.refresh()
        for _ in 0..<200 {
            if !partial.loading && !partial.tokensLoading { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        check(partial.usage != nil && partial.error == nil && partial.tokensError, "History failure does not hide successful allowance")
        model.refreshIfStale(); check(sequence.count == 3, "Opening a fresh panel does not fetch again")
        model.stop()
        if ProcessInfo.processInfo.environment["ALLOWANCE_LIVE_TEST"] == "1" {
            check(try !UsageClient.read().buckets.isEmpty, "Live account read")
            let liveTokens = try TokenActivityClient.read()
            check(liveTokens.dailyUsageBuckets != nil, "Live token activity read")
        }
    }
}
