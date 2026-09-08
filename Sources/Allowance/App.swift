import SwiftUI
import AppKit
@MainActor final class AppController: NSObject, NSApplicationDelegate {
    static weak var shared: AppController?
    private var companion: NSWindow?
    private var settings: NSWindow?
    private var wakeObserver: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        if let iconURL = Bundle.main.url(forResource: "Allowance", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        Model.shared.start()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in Model.shared.refreshIfStale() }
        }
        showWindow(model: Model.shared)
    }
    func showWindow(model: Model) {
        if let companion {
            companion.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = CompanionWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 550), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Allowance"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = NSColor(calibratedWhite: 0.065, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.install(model: model)
        if let screen = NSScreen.screens.first {
            let area = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2,
                                          y: area.midY - window.frame.height / 2))
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        companion = window
    }
    func showSettings() {
        if let settings {
            settings.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 290), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Allowance Settings"
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: .shared))
            if let area = NSScreen.screens.first?.visibleFrame {
                window.setFrameOrigin(NSPoint(x: area.midX - 230, y: area.midY - 145))
            }
            window.makeKeyAndOrderFront(nil)
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(model: .shared)
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        Model.shared.stop()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

}
@main struct AllowanceApp: App {
    @NSApplicationDelegateAdaptor(AppController.self) private var delegate
    @StateObject private var model = Model.shared
    var body: some Scene {
        MenuBarExtra {
            Panel(model: model, isMenuPopover: true)
        } label: {
            Image(systemName: "gauge.with.dots.needle.33percent")
            Text("Allowance")
        }.menuBarExtraStyle(.window)
    }
}
struct Panel: View {
    @ObservedObject var model: Model
    var isMenuPopover = false
    var onHeightChange: ((CGFloat) -> Void)? = nil
    @AppStorage("keepWindowOnTop") private var isPinned = false
    @AppStorage("showAllUsageDetails") private var showAllDetails = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tint = Color(red: 0.30, green: 0.88, blue: 0.73)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text("CODEX CAPACITY")
                    .font(.system(size: 13, weight: .semibold)).tracking(1.3)
                    .foregroundStyle(.primary.opacity(0.9))
            }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 22)

            if let error = model.error {
                VStack(alignment: .leading, spacing: 5) {
                    Label(model.usage == nil ? "Usage unavailable" : "Showing last known usage", systemImage: "wifi.exclamationmark").font(.headline)
                    Text(error).font(.caption).textSelection(.enabled)
                    Button("Setup & connection…") { AppController.shared?.showSettings() }
                        .font(.caption)
                }.foregroundStyle(.orange)
            }
            if let usage = model.usage {
                let buckets = usage.buckets
                let mainIndex = buckets.firstIndex(where: { $0.limitId == "codex" }) ?? buckets.startIndex
                if !buckets.isEmpty {
                    bucketView(buckets[mainIndex], showTitle: buckets[mainIndex].limitId != "codex")
                    let others = buckets.enumerated().filter { $0.offset != mainIndex }
                    if !others.isEmpty {
                        DisclosureGroup(isExpanded: $showAllDetails) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    ForEach(others, id: \.offset) { entry in
                                        bucketView(entry.element, percentageSize: 18)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 14)
                            }.frame(height: 195)
                        } label: {
                            Text("All usage details").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }.tint(tint)
                        .disclosureGroupStyle(SmoothUsageDisclosure())
                    }
                } else {
                    Text("No allowance windows reported for this account.").foregroundStyle(.secondary)
                }
            } else if model.loading {
                HStack { ProgressView().controlSize(.small); Text("Reading account allowance…").foregroundStyle(.secondary) }.padding(.vertical, 22)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    if model.loading { Text("Refreshing…") }
                    else if let date = model.updated {
                        Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
                    } else { Text("No data yet") }
                    Text("Refreshes every 5 minutes")
                        .frame(height: showAllDetails ? 13 : 0, alignment: .top)
                        .opacity(showAllDetails ? 1 : 0)
                        .clipped()
                        .accessibilityHidden(!showAllDetails)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Open companion window") { AppController.shared?.showWindow(model: model) }
                    Button("Settings…") { AppController.shared?.showSettings() }
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .help("More options").accessibilityLabel("More options")
                Button {
                    isPinned.toggle()
                    if isPinned && isMenuPopover {
                        AppController.shared?.showWindow(model: model)
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? tint : Color.primary)
                }.help(isPinned ? "Turn off keep on top" : "Keep on top")
                    .accessibilityLabel("Keep on top")
                    .accessibilityValue(isPinned ? "On" : "Off")
                    .colorMultiply(Color(white: 0.82))
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.disabled(model.loading).help("Refresh usage").accessibilityLabel("Refresh usage").colorMultiply(Color(white: 0.82))
                Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }.help("Quit Allowance").accessibilityLabel("Quit Allowance").colorMultiply(Color(white: 0.82))
            }
        }.padding(.horizontal, 22).padding(.vertical, 14).frame(width: 360)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .modifier(AnimatedPanelHeight(height: proxy.size.height, onHeightChange: onHeightChange))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: showAllDetails)
        .background(WindowLevelBridge(isPinned: isPinned && !isMenuPopover))
        .modifier(DarkGlassSurface())
        .preferredColorScheme(.dark)
        .onAppear { model.refreshIfStale() }
    }
    func bucketView(_ bucket: Bucket, showTitle: Bool = true, percentageSize: CGFloat = 22) -> some View {
        VStack(alignment: .leading, spacing: percentageSize < 22 ? 12 : 6) {
            if showTitle { Text(bucket.title).font(.system(size: 13, weight: .medium)) }
            if bucket.primary == nil && bucket.secondary == nil {
                Text("No allowance windows reported.").font(.caption).foregroundStyle(.secondary)
            }
            if let w = bucket.primary { window(w, percentageSize: percentageSize) }
            if let w = bucket.secondary { window(w, percentageSize: percentageSize) }
        }
    }
    func window(_ w: Window, percentageSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: percentageSize < 22 ? 7 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(w.title).foregroundStyle(.secondary)
                Spacer()
                Text("\(w.remaining, specifier: "%.0f")%").font(.system(size: percentageSize, weight: .medium, design: .rounded)).monospacedDigit()
                Text("left").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: w.remaining, total: 100).progressViewStyle(AllowanceBar(color: w.remaining <= 15 ? .orange : tint)).accessibilityLabel("\(w.title), \(Int(w.remaining)) percent remaining")
            if let timestamp = w.resetsAt {
                let date = Date(timeIntervalSince1970: timestamp)
                Text("Resets \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else { Text("Reset time unavailable").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// Native material follows the user's Reduce Transparency preference.
private struct DarkGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(white: 0.10))
        } else if #available(macOS 26.0, *) {
            content
                .background(Color.black.opacity(0.69))
                .background(DesktopMaterial())
                .glassEffect(.clear.tint(.black.opacity(0.25)), in: .rect(cornerRadius: 20))
        } else {
            content.background(DesktopMaterial())
                .background(Color.black.opacity(0.35))
        }
    }
}
private struct DesktopMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
private struct AllowanceBar: ProgressViewStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule().fill(color.gradient)
                    .overlay {
                        Capsule().fill(.white.opacity(0.32))
                            .frame(height: 1)
                            .padding(.horizontal, 2)
                    }
                    .frame(width: proxy.size.width * (configuration.fractionCompleted ?? 0))
                    .shadow(color: color.opacity(0.40), radius: 3, y: 0)
            }
        }.frame(height: 5)
    }
}

/// Keep the content mounted so height and opacity interpolate in both directions.
private struct SmoothUsageDisclosure: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    configuration.label
                    Spacer()
                }.contentShape(Rectangle()).padding(.vertical, 4)
            }.buttonStyle(.plain)
                .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            configuration.content
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: configuration.isExpanded ? 195 : 0, alignment: .top)
                .opacity(configuration.isExpanded ? 1 : 0)
                .clipped()
                .allowsHitTesting(configuration.isExpanded)
                .accessibilityHidden(!configuration.isExpanded)
        }
    }
}

/// Apply the preference to this hosting window, preserving its original level.
private struct WindowLevelBridge: NSViewRepresentable {
    let isPinned: Bool
    func makeNSView(context: Context) -> LevelView { LevelView() }
    func updateNSView(_ view: LevelView, context: Context) {
        view.isPinned = isPinned
        view.apply()
    }
    final class LevelView: NSView {
        var isPinned = false
        private weak var attachedWindow: NSWindow?
        private var originalLevel: NSWindow.Level = .normal
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if attachedWindow !== window {
                attachedWindow = window
                originalLevel = window?.level ?? .normal
            }
            apply()
        }
        func apply() {
            window?.level = isPinned ? .floating : originalLevel
        }
    }
}
