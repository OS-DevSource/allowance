import Foundation
import Combine

/// One account snapshot and refresh loop are shared by all app surfaces.
@MainActor final class Model: ObservableObject {
    static let shared = Model()
    @Published private(set) var usage: Usage?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?
    @Published var cliPath: String {
        didSet { preferences.set(cliPath, forKey: "codexExecutablePath") }
    }
    private let preferences: UserDefaults
    private let reader: @Sendable (String?) throws -> Usage
    private var timer: Timer?

    init(preferences: UserDefaults = .standard,
         reader: @escaping @Sendable (String?) throws -> Usage = { try UsageClient.read(override: $0) }) {
        self.preferences = preferences
        self.reader = reader
        cliPath = preferences.string(forKey: "codexExecutablePath") ?? ""
    }
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }
    func stop() { timer?.invalidate(); timer = nil }
    func refreshIfStale() {
        if updated.map({ Date().timeIntervalSince($0) >= 300 }) ?? true { refresh() }
    }
    func refresh() {
        guard !loading else { return }
        loading = true
        let path = cliPath.isEmpty ? nil : cliPath
        let reader = reader
        Task {
            do {
                let result = try await Task.detached(priority: .utility) { try reader(path) }.value
                usage = result
                updated = Date()
                error = nil
            } catch {
                self.error = (error as? UsageError)?.localizedDescription ?? UsageError.unavailable.localizedDescription
            }
            loading = false
        }
    }
}
