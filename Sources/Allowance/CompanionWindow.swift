import AppKit
import SwiftUI

/// Follow SwiftUI presentation heights so content and window share one animation.
final class CompanionWindow: NSWindow, NSWindowDelegate {
    private var trackingPosition = false

    func restorePosition() {
        if UserDefaults.standard.object(forKey: "rememberWindowPosition") as? Bool ?? true,
           let saved = UserDefaults.standard.array(forKey: "companionTopLeft") as? [Double],
           saved.count == 2, saved.allSatisfy({ $0.isFinite }) {
            let point = NSPoint(x: saved[0], y: saved[1])
            let areas = NSScreen.screens.map(\.visibleFrame)
            if let area = areas.first(where: { $0.contains(NSPoint(x: point.x, y: point.y - 1)) }) ?? areas.first {
                setFrameTopLeftPoint(WindowPosition.reachableTopLeft(point, size: frame.size, area: area))
            }
        }
        delegate = self
        trackingPosition = true
    }

    func savePosition() {
        guard trackingPosition,
              UserDefaults.standard.object(forKey: "rememberWindowPosition") as? Bool ?? true else { return }
        UserDefaults.standard.set([frame.minX, frame.maxY], forKey: "companionTopLeft")
    }

    func windowDidMove(_ notification: Notification) { savePosition() }

    private var hosting: NSHostingController<AnyView>?
    private var targetHeight: CGFloat = 0
    func install(model: Model) {
        let panel = Panel(model: model, onHeightChange: { [weak self] height in
            DispatchQueue.main.async { self?.resize(to: height) }
        })
        // Keep oversized animated content pinned to the top so growth reveals downward.
        let root = GeometryReader { proxy in
            panel
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
        }
        let host = NSHostingController(rootView: AnyView(root))
        host.sizingOptions = []
        hosting = host
        contentViewController = host
    }
    private func resize(to height: CGFloat) {
        guard height.isFinite, height > 0, ceil(height) != targetHeight else { return }
        targetHeight = ceil(height)
        let content = NSRect(x: 0, y: 0, width: 360, height: ceil(height))
        let newHeight = frameRect(forContentRect: content).height
        var destination = frame
        destination.origin.y += destination.height - newHeight
        destination.size = NSSize(width: 360, height: newHeight)
        setFrame(destination, display: true)
    }
}

/// Reports interpolated presentation sizes, rather than only the final layout size.
struct AnimatedPanelHeight: AnimatableModifier {
    var height: CGFloat
    var onHeightChange: ((CGFloat) -> Void)?

    var animatableData: CGFloat {
        get { height }
        set {
            height = newValue
            onHeightChange?(newValue)
        }
    }

    func body(content: Content) -> some View {
        content.onAppear { onHeightChange?(height) }
            .onChange(of: height) { onHeightChange?($0) }
    }
}
