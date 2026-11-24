import XCTest
@testable import Allowance

final class TokenActivityTests: XCTestCase {
    func testDailyHistoryPreservesZeroAndMissingDates() throws {
        let activity = try TokenActivity.decode(Data(#"{"summary":{"lifetimeTokens":14876244643},"dailyUsageBuckets":[{"startDate":"2026-09-17","tokens":23571621},{"startDate":"2026-09-16","tokens":0}]}"#.utf8))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-17T23:59:00Z"))
        let days = activity.days(now: now)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map { TokenActivity.calendar.component(.weekday, from: $0.date) }, [6, 7, 1, 2, 3, 4, 5])
        XCTAssertEqual(days[6].tokens, 23571621)
        XCTAssertEqual(days[5].tokens, 0)
        XCTAssertNil(days[4].tokens)
        XCTAssertNil(activity.days(now: now.addingTimeInterval(120))[6].tokens)
        XCTAssertEqual(activity.summary?.lifetimeTokens, 14876244643)
    }
    func testSundayKeepsPreviousSixDays() throws {
        let activity = try TokenActivity.decode(Data(#"{"dailyUsageBuckets":[{"startDate":"2026-09-19","tokens":10}]}"#.utf8))
        let formatter = ISO8601DateFormatter()
        let sunday = try XCTUnwrap(formatter.date(from: "2026-09-13T00:00:00Z"))
        let saturday = try XCTUnwrap(formatter.date(from: "2026-09-19T23:59:00Z"))
        XCTAssertEqual(activity.days(now: sunday).first?.date,
                       formatter.date(from: "2026-09-07T00:00:00Z"))
        XCTAssertNil(activity.days(now: sunday).last?.tokens)
        XCTAssertEqual(activity.days(now: saturday).first?.date, sunday)
        XCTAssertEqual(activity.days(now: saturday).last?.tokens, 10)
        let nextSunday = activity.days(now: saturday.addingTimeInterval(120))
        XCTAssertEqual(nextSunday.first?.date, formatter.date(from: "2026-09-14T00:00:00Z"))
        XCTAssertEqual(nextSunday[5].tokens, 10)
        XCTAssertNil(nextSunday[6].tokens)
    }
    func testWeekOrderedBarsKeepRollingDatesAcrossSunday() throws {
        let activity = try TokenActivity.decode(Data(#"{"dailyUsageBuckets":[{"startDate":"2026-09-19","tokens":10}]}"#.utf8))
        let calendar = TokenActivity.calendar
        let saturday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T23:59:00Z"))
        let sunday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-20T00:01:00Z"))
        let saturdayBars = activity.weekOrderedDays(now: saturday)
        let sundayBars = activity.weekOrderedDays(now: sunday)
        XCTAssertEqual(saturdayBars.map { calendar.component(.weekday, from: $0.date) }, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(sundayBars.map { calendar.component(.weekday, from: $0.date) }, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(saturdayBars[6].tokens, 10)
        XCTAssertEqual(sundayBars[6].tokens, 10)
        XCTAssertEqual(sundayBars[0].date, calendar.startOfDay(for: sunday))
        XCTAssertNil(sundayBars[0].tokens)
    }
    func testReportingDayRollsAtUTCMidnight() throws {
        let activity = try TokenActivity.decode(Data(#"{"dailyUsageBuckets":[{"startDate":"2026-11-24","tokens":10},{"startDate":"2026-11-25","tokens":25}]}"#.utf8))
        let formatter = ISO8601DateFormatter()
        let before = try XCTUnwrap(formatter.date(from: "2026-11-24T23:59:59Z"))
        let after = try XCTUnwrap(formatter.date(from: "2026-11-25T00:00:00Z"))
        let localMidnight = try XCTUnwrap(formatter.date(from: "2026-11-25T06:00:00Z"))
        XCTAssertEqual(activity.days(now: before).last?.tokens, 10)
        XCTAssertEqual(activity.days(now: after).last?.tokens, 25)
        XCTAssertEqual(activity.days(now: localMidnight).last?.tokens, 25)
        XCTAssertEqual(activity.weekOrderedDays(now: after)[3].tokens, 25)
        XCTAssertEqual(activity.weekOrderedDays(now: after)[3].date, after)
        XCTAssertEqual(activity.days(now: localMidnight).map(\.date),
                       activity.days(now: localMidnight.addingTimeInterval(-1)).map(\.date))
    }
    func testNullableHistoryIsNotZeroUsage() throws {
        let activity = try TokenActivity.decode(Data(#"{"summary":null,"dailyUsageBuckets":null}"#.utf8))
        XCTAssertNil(activity.summary)
        XCTAssertNil(activity.dailyUsageBuckets)
        XCTAssertTrue(activity.days().allSatisfy { $0.tokens == nil })
    }
    func testRejectsMalformedHistory() {
        for fixture in [
            #"{}"#,
            #"{"dailyUsageBuckets":[{"startDate":"2026-02-30","tokens":1}]}"#,
            #"{"dailyUsageBuckets":[{"startDate":"2026-09-17","tokens":-1}]}"#,
            #"{"dailyUsageBuckets":[{"startDate":"2026-09-17","tokens":1},{"startDate":"2026-09-17","tokens":2}]}"#
        ] {
            XCTAssertThrowsError(try TokenActivity.decode(Data(fixture.utf8))) {
                XCTAssertEqual($0 as? UsageError, .malformed)
            }
        }
    }
    func testCompactFormatting() {
        XCTAssertEqual(TokenActivity.compact(0), "0")
        XCTAssertEqual(TokenActivity.compact(800), "800")
        XCTAssertEqual(TokenActivity.compact(23571621), "23.6M")
        XCTAssertEqual(TokenActivity.compact(14876244643), "14.9B")
    }
    func testLiveReadWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["ALLOWANCE_LIVE_TEST"] == "1" else { throw XCTSkip("Opt-in live account read") }
        XCTAssertNotNil(try TokenActivityClient.read().dailyUsageBuckets)
    }
}
