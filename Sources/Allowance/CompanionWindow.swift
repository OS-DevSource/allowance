import AppKit
import SwiftUI

/// Follow SwiftUI presentation heights so content and window share one animation.
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
