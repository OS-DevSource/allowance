import AppKit
import SwiftUI
import QuartzCore

/// Own fitting-size changes explicitly so AppKit cannot snap the window closed.
final class CompanionWindow: NSWindow {
    private var hosting: NSHostingController<AnyView>?
    private var targetHeight: CGFloat = 0
    func install(model: Model) {
        let panel = Panel(model: model, onHeightChange: { [weak self] height in
            DispatchQueue.main.async { self?.resize(to: height) }
        })
        let host = NSHostingController(rootView: AnyView(panel.fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: .infinity, alignment: .top)))
        host.sizingOptions = []
        hosting = host
        contentViewController = host
    }
    private func resize(to height: CGFloat) {
        guard height.isFinite, height > 0, abs(height - targetHeight) > 0.5 else { return }
        targetHeight = height
        let content = NSRect(x: 0, y: 0, width: 360, height: ceil(height))
        let newHeight = frameRect(forContentRect: content).height
        var destination = frame
        destination.origin.y += destination.height - newHeight
        destination.size = NSSize(width: 360, height: newHeight)
        guard isVisible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            setFrame(destination, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(destination, display: true)
        }
    }
}
