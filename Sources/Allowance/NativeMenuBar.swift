import AppKit
import SwiftUI

/// Let AppKit draw the menu chrome, while the account summary remains compact.
@MainActor final class NativeMenuBar: NSObject, NSMenuDelegate {
    private let model: Model
    private let statusItem: NSStatusItem
    private let menu = NSMenu(title: "Allowance")

    init(model: Model) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let url = Bundle.main.url(forResource: "AllowanceMenuBar", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 16, height: 16)
            image.isTemplate = true
            statusItem.button?.image = image
        }
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Allowance"
        statusItem.button?.setAccessibilityLabel("Allowance")
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refreshIfStale()
        menu.removeAllItems()

        let buckets = model.usage?.buckets ?? []
        let mainIndex = buckets.firstIndex(where: { $0.limitId == "codex" }) ?? (buckets.isEmpty ? nil : 0)
        let main = mainIndex.map { buckets[$0] }
        let summary = MenuCapacitySummary(bucket: main, loading: model.loading)
        let host = NSHostingView(rootView: summary)
        host.frame = NSRect(x: 0, y: 0, width: 300, height: summary.height)
        host.sizingOptions = []
        let summaryItem = NSMenuItem()
        summaryItem.view = host
        menu.addItem(summaryItem)

        if model.error != nil {
            menu.addItem(informationalItem(model.usage == nil ? "Usage unavailable" : "Showing last known usage"))
            menu.addItem(actionItem("Setup & connection…", #selector(openSettings)))
        }

        let otherBuckets = buckets.enumerated().filter { $0.offset != mainIndex }.map(\.element)
        if !otherBuckets.isEmpty {
            let details = NSMenuItem(title: "All usage details", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "All usage details")
            for (index, bucket) in otherBuckets.enumerated() {
                if index > 0 { submenu.addItem(.separator()) }
                submenu.addItem(informationalItem(bucket.title))
                let windows = [bucket.primary, bucket.secondary].compactMap { $0 }
                if windows.isEmpty { submenu.addItem(informationalItem("No allowance windows reported")) }
                for window in windows {
                    submenu.addItem(informationalItem("\(window.title): \(Int(window.remaining.rounded()))% left"))
                    submenu.addItem(informationalItem(resetLabel(for: window)))
                }
            }
            details.submenu = submenu
            menu.addItem(details)
        }

        menu.addItem(informationalItem(model.updated.map {
            "Updated \($0.formatted(date: .omitted, time: .shortened))"
        } ?? "No data yet"))
        if model.loading { menu.addItem(informationalItem("Refreshing…")) }
        menu.addItem(.separator())
        menu.addItem(actionItem("Open companion window", #selector(openCompanion)))
        let pin = actionItem("Keep on top", #selector(togglePin))
        pin.state = UserDefaults.standard.bool(forKey: "keepWindowOnTop") ? .on : .off
        menu.addItem(pin)
        let refresh = actionItem("Refresh usage", #selector(refreshUsage))
        refresh.isEnabled = !model.loading
        menu.addItem(refresh)
        menu.addItem(actionItem("Settings…", #selector(openSettings)))
        menu.addItem(.separator())
        let quit = actionItem("Quit Allowance", #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    private func informationalItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func resetLabel(for window: Window) -> String {
        MenuResetDate.label(timestamp: window.resetsAt)
    }

    @objc private func openCompanion() { AppController.shared?.showWindow(model: model) }
    @objc private func openSettings() { AppController.shared?.showSettings() }
    @objc private func refreshUsage() { model.refresh() }
    @objc private func togglePin() {
        let preferences = UserDefaults.standard
        preferences.set(!preferences.bool(forKey: "keepWindowOnTop"), forKey: "keepWindowOnTop")
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

private struct MenuCapacitySummary: View {
    let bucket: Bucket?
    let loading: Bool
    private let tint = Color(red: 0.30, green: 0.88, blue: 0.73)
    private var windows: [Window] { [bucket?.primary, bucket?.secondary].compactMap { $0 } }
    var height: CGFloat { 52 + CGFloat(windows.count) * 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(tint).accessibilityHidden(true)
                Text("CODEX CAPACITY")
                    .font(.system(size: 12, weight: .semibold)).tracking(0.8)
            }
            if windows.isEmpty {
                Text(loading ? "Reading account allowance…" : bucket == nil ? "No data yet" : "No allowance windows reported")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(window.title).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(window.remaining.rounded()))% left").monospacedDigit()
                    }.font(.system(size: 12))
                    ProgressView(value: window.remaining, total: 100)
                        .controlSize(.small).tint(window.remaining <= 15 ? .orange : tint)
                        .accessibilityLabel("\(window.title), \(Int(window.remaining)) percent remaining")
                    Text(window.resetsAt.map {
                        MenuResetDate.label(timestamp: $0)
                    } ?? "Reset time unavailable")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(width: 300, height: height, alignment: .topLeading)
    }
}

private enum MenuResetDate {
    static func label(timestamp: Double?) -> String {
        guard let timestamp else { return "Reset time unavailable" }
        let date = Date(timeIntervalSince1970: timestamp)
        let day = date.formatted(.dateTime.month(.defaultDigits).day())
        let time = date.formatted(date: .omitted, time: .shortened)
        return "Resets \(day) · \(time)"
    }
}
