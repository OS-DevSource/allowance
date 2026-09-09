import SwiftUI
import AppKit

@MainActor private final class SettingsState: ObservableObject {
    @Published var selectionError: String?
}

struct SettingsView: View {
    @ObservedObject var model: Model
    @AppStorage("rememberWindowPosition") private var rememberWindowPosition = true
    @StateObject private var state = SettingsState()
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Window").font(.headline)
            Toggle("Remember window position", isOn: $rememberWindowPosition)
                .onChange(of: rememberWindowPosition) { enabled in
                    if enabled { AppController.shared?.rememberCurrentPosition() }
                }
            Text("Reopen the companion where you last placed it. Saved only on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Codex connection").font(.title2.bold())
            Text("Allowance reads usage through your installed, signed-in Codex CLI.")
                .foregroundStyle(.secondary)
            Text(model.cliPath.isEmpty ? "Automatic detection" : "Selected executable").font(.headline)
            Text((try? CLIResolver.resolve(override: model.cliPath.isEmpty ? nil : model.cliPath)) ?? "Codex not found")
                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .lineLimit(3)
            HStack {
                Button("Choose Codex…") { chooseExecutable() }.disabled(model.loading)
                Button("Use automatic detection") { model.cliPath = ""; state.selectionError = nil; model.refresh() }
                    .disabled(model.cliPath.isEmpty || model.loading)
            }
            if let selectionError = state.selectionError { Text(selectionError).font(.caption).foregroundStyle(.orange) }
            Divider()
            Text("Need to sign in? Run codex login in Terminal, then click Refresh. To check your CLI version, run codex --version.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Link("Official Codex setup", destination: URL(string: "https://developers.openai.com/codex/cli/")!)
                Spacer()
                Button(model.loading ? "Refreshing…" : "Refresh") { model.refresh() }.disabled(model.loading)
            }
        }.padding(22).frame(width: 460)
    }
    private func chooseExecutable() {
        let picker = NSOpenPanel()
        picker.level = .modalPanel
        picker.resolvesAliases = false
        picker.title = "Choose the Codex executable"
        picker.prompt = "Use Codex"
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = false
        picker.showsHiddenFiles = true
        picker.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        guard picker.runModal() == .OK, let url = picker.url else { return }
        guard CLIResolver.valid(url.path) else {
            state.selectionError = "Select an executable file, not a folder or app bundle."
            return
        }
        model.cliPath = url.path
        state.selectionError = nil
        model.refresh()
    }
}
