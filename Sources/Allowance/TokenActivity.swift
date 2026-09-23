import Foundation

/// Service date labels are preserved; the rolling seven-day window follows the user's time zone.
struct TokenActivity: Decodable {
    struct Summary: Decodable {
        let lifetimeTokens: Int64?
    }
    struct Bucket: Decodable {
        let startDate: String
        let tokens: Int64
    }
    struct Day: Identifiable {
        let date: Date
        let tokens: Int64?
        var id: Date { date }
    }
    let summary: Summary?
    let dailyUsageBuckets: [Bucket]?

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    static func displayCalendar(timeZone: TimeZone = .autoupdatingCurrent) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
    private static func date(_ key: String, calendar: Calendar = Self.calendar) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        return date
    }
    static func decode(_ data: Data) throws -> TokenActivity {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object.keys.contains("summary") || object.keys.contains("dailyUsageBuckets"),
              let activity = try? JSONDecoder().decode(TokenActivity.self, from: data) else { throw UsageError.malformed }
        var dates = Set<String>()
        for bucket in activity.dailyUsageBuckets ?? [] {
            guard bucket.tokens >= 0, date(bucket.startDate) != nil,
                  dates.insert(bucket.startDate).inserted else { throw UsageError.malformed }
        }
        if let lifetime = activity.summary?.lifetimeTokens, lifetime < 0 { throw UsageError.malformed }
        return activity
    }
    func days(now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) -> [Day] {
        let calendar = Self.displayCalendar(timeZone: timeZone)
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -6, to: today)!
        let counts = Dictionary((dailyUsageBuckets ?? []).compactMap { bucket in
            Self.date(bucket.startDate, calendar: calendar).map { ($0, bucket.tokens) }
        }, uniquingKeysWith: { first, _ in first })
        return (0...6).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDay).map {
                Day(date: $0, tokens: counts[$0])
            }
        }
    }
    /// Keep the rolling dates, but place their bars in the familiar Sunday–Saturday order.
    func weekOrderedDays(now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) -> [Day] {
        let calendar = Self.displayCalendar(timeZone: timeZone)
        return days(now: now, timeZone: timeZone).sorted {
            calendar.component(.weekday, from: $0.date) < calendar.component(.weekday, from: $1.date)
        }
    }
    static func compact(_ tokens: Int64) -> String {
        let value = Double(tokens)
        if tokens >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
        if tokens >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return String(tokens)
    }
}

struct TokenActivityClient {
    static func read(override: String? = nil) throws -> TokenActivity {
        try read(executable: CLIResolver.resolve(override: override))
    }
    static func read(executable: String, timeout: TimeInterval = 25) throws -> TokenActivity {
        try TokenActivity.decode(UsageClient.request(executable: executable, method: "account/usage/read", timeout: timeout))
    }
}
