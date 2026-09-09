import AppKit
import XCTest
@testable import Allowance

final class WindowPositionTests: XCTestCase {
    func testPreservesReachablePosition() {
        let area = NSRect(x: 0, y: 25, width: 1440, height: 875)
        let point = NSPoint(x: 8, y: 892)
        XCTAssertEqual(WindowPosition.reachableTopLeft(point, size: NSSize(width: 360, height: 410), area: area), point)
    }

    func testDisconnectedDisplayFallsBackInsideVisibleArea() {
        let area = NSRect(x: 0, y: 25, width: 1440, height: 875)
        XCTAssertEqual(WindowPosition.reachableTopLeft(NSPoint(x: 2500, y: -500), size: NSSize(width: 360, height: 410), area: area), NSPoint(x: 1080, y: 47))
    }

    func testNegativeDisplayCoordinatesAndOversizedWindow() {
        let area = NSRect(x: -1280, y: 0, width: 1280, height: 720)
        XCTAssertEqual(WindowPosition.reachableTopLeft(NSPoint(x: -1200, y: 700), size: NSSize(width: 360, height: 410), area: area), NSPoint(x: -1200, y: 700))
        XCTAssertEqual(WindowPosition.reachableTopLeft(.zero, size: NSSize(width: 1500, height: 900), area: area), NSPoint(x: -1280, y: 22))
    }
}
