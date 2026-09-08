import XCTest
@testable import Allowance
final class UsageTests: XCTestCase {
    func testClampsRemainingAndUsesDuration() {
        XCTAssertEqual(Window(usedPercent: 110, windowDurationMins: 10080, resetsAt: nil).remaining, 0)
        XCTAssertEqual(Window(usedPercent: -5, windowDurationMins: 300, resetsAt: nil).remaining, 100)
        XCTAssertEqual(Window(usedPercent: 9, windowDurationMins: 10080, resetsAt: nil).title, "Weekly")
    }
    func testBucketsPreferMapAndPreserveMissingWindows() throws {
        let data = Data(#"{"rateLimits":{"limitId":"legacy","primary":null,"secondary":null},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":9,"windowDurationMins":10080,"resetsAt":null},"secondary":null}}}"#.utf8)
        let result = try JSONDecoder().decode(Usage.self, from: data)
        XCTAssertEqual(result.buckets.count, 1)
        XCTAssertEqual(result.buckets.first?.primary?.remaining, 91)
        XCTAssertNil(result.buckets.first?.secondary)
    }
    func testLegacyFallback() throws {
        let data = Data(#"{"rateLimits":{"limitId":"codex","primary":null,"secondary":null},"rateLimitsByLimitId":null}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(Usage.self, from: data).buckets.count, 1)
    }
    func testLiveReadWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["ALLOWANCE_LIVE_TEST"] == "1" else { throw XCTSkip("Opt-in live account read") }
        XCTAssertFalse(try UsageClient.read().buckets.isEmpty)
    }
}
