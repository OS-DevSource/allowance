import XCTest
@testable import Allowance
final class UsageTests: XCTestCase {
    func testClampsRemainingAndUsesDuration() {
        XCTAssertEqual(Window(usedPercent: 110, windowDurationMins: 10080, resetsAt: nil).remaining, 0)
        XCTAssertEqual(Window(usedPercent: -5, windowDurationMins: 300, resetsAt: nil).remaining, 100)
        XCTAssertEqual(Window(usedPercent: 9, windowDurationMins: 10080, resetsAt: nil).title, "Weekly")
    }
    func testCapacityColorThresholds() {
        func level(_ remaining: Double) -> CapacityLevel {
            Window(usedPercent: 100 - remaining, windowDurationMins: nil, resetsAt: nil).capacityLevel
        }
        XCTAssertEqual(level(20.1), .normal)
        XCTAssertEqual(level(20), .warning)
        XCTAssertEqual(level(10.1), .warning)
        XCTAssertEqual(level(10), .critical)
        XCTAssertEqual(level(0), .critical)
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
