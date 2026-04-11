import Foundation

// MARK: - Response Cache
// Actor-based LRU cache for Foundation Models responses and direct-answer bypasses.
// Keyed on (normalizedQuery, walletBalanceBucket, intentKey).
//
// TTL policy:
//   Knowledge / FAQ   → 24 hours  (content doesn't change)
//   General chat      → 2 minutes (wallet context may drift)
//   Price             → 30 s      (matches PriceService.cacheTTL)
//   Balance           → 15 s      (balance can change quickly)
//   Transactions      → 0         (never cached — always unique)

actor ResponseCache {

    // MARK: - Cache Key

    struct CacheKey: Hashable {
        /// Lowercased, whitespace-trimmed query text.
        let query: String
        /// Wallet SOL balance bucketed to whole number (e.g. "2" for 2.34 SOL).
        /// Empty string for wallet-independent intents (knowledge, FAQ).
        let walletBucket: String
        /// Short intent identifier string ("faq", "balance", "price", "knowledge", "chat").
        let intentKey: String
    }

    // MARK: - Internal Entry

    private struct Entry {
        let response: String
        let expiresAt: Date
        var lastAccessed: Date
    }

    // MARK: - State

    private var store: [CacheKey: Entry] = [:]
    private let maxEntries = 80

    // MARK: - TTL Policy (nonisolated — no actor state needed)

    nonisolated static func ttl(for intent: QueryIntent) -> TimeInterval {
        switch intent {
        case .faqAnswer:        return 86_400   // 24 hours
        case .directKnowledge:  return 86_400   // 24 hours
        case .generalChat:      return 120       // 2 minutes
        case .directPrice:      return 30        // matches PriceService.cacheTTL
        case .directBalance:    return 15        // balance changes quickly
        case .toolTransaction:  return 0         // never cache; always unique
        }
    }

    // MARK: - Key Factory (nonisolated helper)

    nonisolated static func makeKey(
        query: String,
        intent: QueryIntent,
        walletBalance: Double
    ) -> CacheKey {
        let normalized = query
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Wallet-independent intents share keys regardless of balance
        let bucket: String
        switch intent {
        case .faqAnswer, .directKnowledge:
            bucket = ""
        default:
            bucket = String(format: "%.0f", floor(walletBalance))
        }

        let intentKey: String
        switch intent {
        case .faqAnswer:        intentKey = "faq"
        case .directBalance:    intentKey = "balance"
        case .directPrice:      intentKey = "price"
        case .directKnowledge:  intentKey = "knowledge"
        case .toolTransaction:  intentKey = "tx"
        case .generalChat:      intentKey = "chat"
        }

        return CacheKey(query: normalized, walletBucket: bucket, intentKey: intentKey)
    }

    // MARK: - Public API

    func get(key: CacheKey) -> String? {
        guard var entry = store[key] else { return nil }
        guard Date() < entry.expiresAt else {
            store.removeValue(forKey: key)
            return nil
        }
        entry.lastAccessed = Date()
        store[key] = entry
        return entry.response
    }

    func set(_ response: String, for key: CacheKey, ttl: TimeInterval) {
        guard ttl > 0 else { return }
        evictIfNeeded()
        store[key] = Entry(
            response: response,
            expiresAt: Date().addingTimeInterval(ttl),
            lastAccessed: Date()
        )
    }

    /// Remove all balance-keyed entries — call after a confirmed balance change.
    func invalidateBalance() {
        store = store.filter { $0.key.intentKey != "balance" }
    }

    /// Remove all cached entries (e.g. on wallet switch).
    func invalidateAll() {
        store.removeAll()
    }

    // MARK: - LRU Eviction

    private func evictIfNeeded() {
        // First pass: remove expired entries
        let now = Date()
        store = store.filter { $0.value.expiresAt > now }
        guard store.count >= maxEntries else { return }
        // Second pass: evict least-recently-accessed
        if let oldest = store.min(by: { $0.value.lastAccessed < $1.value.lastAccessed }) {
            store.removeValue(forKey: oldest.key)
        }
    }
}
