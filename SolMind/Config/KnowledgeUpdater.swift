import Foundation

// MARK: - OPT-09: Remote Knowledge Block Updater
//
// Fetches a lightweight JSON config from a CDN endpoint on app launch.
// Allows the systemBlock and FAQ hints to be updated without an app release —
// critical for a fast-moving ecosystem like Solana where protocol facts change
// (new tokens, programs, APY rates, devnet behaviours) every few weeks.
//
// Security: response is validated against a known schema before being stored.
// No code is executed from the remote payload — only plain String values.
// Unknown keys are ignored; missing keys leave the compiled-in defaults active.
//
// Payload schema (totals < 4KB):
// {
//   "version": "2026.04",          // YYYY.MM format
//   "systemBlock": "...",           // optional override for SolanaKnowledge.compiledSystemBlock
//   "minAppVersion": "1.0"          // optional: ignore on older builds
// }

@Observable
final class KnowledgeUpdater {
    static let shared = KnowledgeUpdater()

    // MARK: - State

    /// Non-nil when a remote override is active. SolanaKnowledge.systemBlock reads this.
    private(set) var overrideSystemBlock: String?

    /// Version string from last successful fetch (e.g. "2026.04").
    private(set) var remoteVersion: String?

    /// True during an in-flight fetch.
    private(set) var isFetching = false

    // MARK: - Config

    // Replace with your actual CDN URL before shipping to production.
    private let configURL = URL(string: "https://raw.githubusercontent.com/solmind-app/config/main/knowledge.json")

    private enum Key {
        static let systemBlock  = "knowledge.systemBlock.override"
        static let version      = "knowledge.version"
        static let fetchedAt    = "knowledge.fetchedAt"
    }

    /// Minimum seconds between remote fetches (6 hours).
    private let fetchIntervalSeconds: TimeInterval = 6 * 60 * 60

    // MARK: - Lifecycle

    private init() {
        loadFromDefaults()
    }

    // MARK: - Public API

    /// Call once on app launch (e.g. from SolMindApp.onAppear).
    func fetchIfNeeded() async {
        guard shouldFetch() else { return }
        await fetch()
    }

    /// Force a refresh regardless of last-fetch time (e.g. from Settings).
    func forceRefresh() async {
        await fetch()
    }

    /// Remove any remote override — compiled-in defaults become active again.
    func clearOverride() {
        overrideSystemBlock = nil
        remoteVersion = nil
        UserDefaults.standard.removeObject(forKey: Key.systemBlock)
        UserDefaults.standard.removeObject(forKey: Key.version)
        UserDefaults.standard.removeObject(forKey: Key.fetchedAt)
    }

    // MARK: - Fetch

    private func fetch() async {
        guard let url = configURL else { return }
        isFetching = true
        defer { isFetching = false }

        do {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                     timeoutInterval: 8)
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            guard data.count < 8_192 else { return }  // sanity limit: reject oversized payloads

            try applyPayload(data)
            UserDefaults.standard.set(Date(), forKey: Key.fetchedAt)
        } catch {
            // Silent failure — compiled-in defaults remain active.
        }
    }

    // MARK: - Payload Parsing

    private func applyPayload(_ data: Data) throws {
        struct Payload: Decodable {
            let version: String
            let systemBlock: String?
            let minAppVersion: String?
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)

        // Check minimum app version constraint if present
        if let minVersion = payload.minAppVersion {
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            guard appVersion.compare(minVersion, options: .numeric) != .orderedAscending else { return }
        }

        // Apply systemBlock override if provided and non-empty
        if let block = payload.systemBlock, !block.isEmpty {
            // Safety: reject if the payload looks like a prompt injection attempt
            // (i.e., contains adversarial instruction fragments targeting the AI)
            guard !looksLikeInjection(block) else { return }
            // Safety: reject if the block contains a raw base58 string ≥32 chars —
            // these trigger Apple's n-gram locale classifier and cause
            // GenerationError.unsupportedLanguageOrLocale on every subsequent session.
            guard !containsBase58Trigger(block) else { return }
            overrideSystemBlock = block
            UserDefaults.standard.set(block, forKey: Key.systemBlock)
        }

        remoteVersion = payload.version
        UserDefaults.standard.set(payload.version, forKey: Key.version)
    }

    // MARK: - Base58 Locale Trigger Guard

    /// Reject remote payloads that contain a base58 string ≥ 32 chars.
    /// Such strings trigger Apple's n-gram locale classifier and produce
    /// GenerationError.unsupportedLanguageOrLocale on every subsequent FM session.
    private func containsBase58Trigger(_ text: String) -> Bool {
        text.range(of: "[1-9A-HJ-NP-Za-km-z]{32,}", options: .regularExpression) != nil
    }

    // MARK: - Injection Guard

    /// Reject remote payloads that contain adversarial instruction fragments.
    /// Checks for common prompt injection patterns targeting the on-device FM.
    private func looksLikeInjection(_ text: String) -> Bool {
        let lower = text.lowercased()
        let injectionPatterns = [
            "ignore previous instructions",
            "ignore all instructions",
            "disregard your instructions",
            "you are now",
            "new persona",
            "forget your",
            "reveal your",
            "send me your",
            "provide your private key",
            "ignore safety"
        ]
        return injectionPatterns.contains { lower.contains($0) }
    }

    // MARK: - UserDefaults Persistence

    private func loadFromDefaults() {
        overrideSystemBlock = UserDefaults.standard.string(forKey: Key.systemBlock)
        remoteVersion       = UserDefaults.standard.string(forKey: Key.version)
    }

    private func shouldFetch() -> Bool {
        guard let lastFetch = UserDefaults.standard.object(forKey: Key.fetchedAt) as? Date else {
            return true  // never fetched
        }
        return Date().timeIntervalSince(lastFetch) >= fetchIntervalSeconds
    }
}
