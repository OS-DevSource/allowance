import Foundation
import CoreGraphics

/// Keep the title bar reachable after a display or resolution change.
enum WindowPosition {
    static func reachableTopLeft(_ point: NSPoint, size: NSSize, area: NSRect) -> NSPoint {
        // Content height changes during launch; clamp the title bar, not the temporary height.
        NSPoint(x: min(max(point.x, area.minX), max(area.minX, area.maxX - size.width)),
                y: min(max(point.y, min(area.maxY, area.minY + 22)), area.maxY))
    }
}
