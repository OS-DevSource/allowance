import AppKit

// Original seven-circle honeycomb artwork matching the header; no external art or fonts.
let destination = CommandLine.arguments.dropFirst().first ?? "Assets"
let directory = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let iconset = directory.appendingPathComponent("Allowance.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func draw(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let rect = NSRect(x: 64, y: 64, width: 896, height: 896)
    let background = NSBezierPath(roundedRect: rect, xRadius: 205, yRadius: 205)
    NSGradient(starting: NSColor(calibratedWhite: 0.18, alpha: 1), ending: NSColor(calibratedWhite: 0.055, alpha: 1))!.draw(in: background, angle: -70)
    NSColor.white.withAlphaComponent(0.12).setStroke(); background.lineWidth = 3; background.stroke()
    let teal = NSColor(calibratedRed: 0.30, green: 0.88, blue: 0.73, alpha: 1)
    let radius: CGFloat = 79
    let spacing: CGFloat = 178
    let centers = [NSPoint(x: 512, y: 512)] + (0..<6).map { index in
        let angle = CGFloat(index) * .pi / 3
        return NSPoint(x: 512 + spacing * cos(angle), y: 512 + spacing * sin(angle))
    }
    for center in centers {
        let dot = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                            width: radius * 2, height: radius * 2))
        teal.setFill()
        dot.fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try draw(size: points * scale).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
try draw(size: 1024).write(to: directory.appendingPathComponent("icon.png"))

// A compact, transparent mark for the menu bar, without the app icon's tile.
let menuSize = 32
let menuRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: menuSize, pixelsHigh: menuSize,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: menuRep)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: menuSize, height: menuSize).fill()
let menuCenter = CGFloat(menuSize) / 2
let menuSpacing: CGFloat = 9.6
let menuRadius: CGFloat = 4.1
let menuCenters = [NSPoint(x: menuCenter, y: menuCenter)] + (0..<6).map { index in
    let angle = CGFloat(index) * .pi / 3
    return NSPoint(x: menuCenter + menuSpacing * cos(angle),
                   y: menuCenter + menuSpacing * sin(angle))
}
let menuTint = NSColor.black
for center in menuCenters {
    menuTint.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - menuRadius, y: center.y - menuRadius,
                               width: menuRadius * 2, height: menuRadius * 2)).fill()
}
NSGraphicsContext.restoreGraphicsState()
try menuRep.representation(using: .png, properties: [:])!
    .write(to: directory.appendingPathComponent("AllowanceMenuBar.png"))
