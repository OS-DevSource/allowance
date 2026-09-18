import Foundation
import Combine

/// One account snapshot and refresh loop are shared by all app surfaces.
@MainActor final class Model: ObservableObject {
    static let shared = Model()
    @Published private(set) var usage: Usage?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?
    @Published private(set) var tokenActivity: TokenActivity?
    @Published private(set) var tokensLoading = false
    @Published private(set) var tokensError = false
    @Published private(set) var tokensUpdated: Date?
    @Published var cliPath: String {
        didSet { preferences.set(cliPath, forKey: "codexExecutablePath") }
    }
    private let preferences: UserDefaults
    private let reader: @Sendable (String?) throws -> Usage
    private let tokenReader: @Sendable (String?) throws -> TokenActivity
    private var timer: Timer?

    init(preferences: UserDefaults = .standard,
         reader: @escaping @Sendable (String?) throws -> Usage = { try UsageClient.read(override: $0) },
         tokenReader: @escaping @Sendable (String?) throws -> TokenActivity = { try TokenActivityClient.read(override: $0) }) {
        self.preferences = preferences
        self.reader = reader
        self.tokenReader = tokenReader
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
        else if tokensUpdated.map({ Date().timeIntervalSince($0) >= 300 }) ?? true { refreshTokens() }
    }
    func refresh() {
        refreshTokens()
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
    private func refreshTokens() {
        guard !tokensLoading else { return }
        tokensLoading = true
        let path = cliPath.isEmpty ? nil : cliPath
        let tokenReader = tokenReader
        Task {
            do {
                tokenActivity = try await Task.detached(priority: .utility) { try tokenReader(path) }.value
                tokensUpdated = Date()
                tokensError = false
            } catch {
                // A history failure must not invalidate the independent allowance snapshot.
                tokensError = true
            }
            tokensLoading = false
        }
    }
}
