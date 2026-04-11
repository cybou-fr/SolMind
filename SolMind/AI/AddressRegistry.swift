import Foundation

// MARK: - Address Registry
//
// Problem: Foundation Models' language classifier detects base58 Solana addresses
// (32-88 chars) as Croatian/Catalan and throws unsupportedLanguageOrLocale.
// We cannot put raw addresses into the FM prompt. But tools like SendTool NEED the
// real recipient address to build and sign transactions.
//
// Solution: Pre-extract addresses from the user's message BEFORE building the FM prompt.
// Store them here with short [addr0] / [addr1] tags. The prompt uses the tags.
// Tools resolve the tags back to full addresses at call time.
//
// Thread safety: actor isolation guarantees one-at-a-time access.
// Re-entrancy: since isProcessing guards sendMessage() to one active call, no concurrent
// modifiers. clear() is called at the start of every sendMessage() run.

actor AddressRegistry {
    static let shared = AddressRegistry()
    private init() {}

    // Tag → full base58 address
    private var registry: [String: String] = [:]
    private var counter = 0

    // MARK: - Extraction

    /// Replace all base58 addresses in `text` with [addr0], [addr1], ... tags.
    /// Stores tag → fullAddress in the registry for later resolution by tools.
    /// Returns the modified text safe for FM prompt injection.
    func processUserText(_ text: String) -> String {
        clear()
        guard let regex = base58Regex else { return text }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard !matches.isEmpty else { return text }

        var result = text
        // Process right-to-left so earlier offsets remain valid after each replacement.
        for match in matches.reversed() {
            guard let swiftRange = Range(match.range, in: result) else { continue }
            let address = String(result[swiftRange])
            let tag = "[addr\(counter)]"
            counter += 1
            registry[tag] = address
            result.replaceSubrange(swiftRange, with: tag)
        }
        return result
    }

    // MARK: - Resolution

    /// Resolve a tag (e.g. "[addr0]") or an already-full address back to the full address.
    ///
    /// Resolution order:
    ///   1. Already a 32+ char base58 address → return as-is
    ///   2. Exact tag match like "[addr0]" → registry lookup
    ///   3. Suffix match → FM sometimes trims surrounding brackets; match by last 4 chars
    func resolve(_ key: String) -> String? {
        // Already a full address — pass directly (covers cases where AI echoes the real address)
        if key.count >= 32 { return key }
        // Exact tag match
        if let full = registry[key] { return full }
        // Fuzzy: match by the last 4 non-space characters (e.g. FM outputs "addr0" without brackets)
        let tail = key.trimmingCharacters(in: .init(charactersIn: "[]")).lowercased()
        if let entry = registry.first(where: { $0.key.trimmingCharacters(in: .init(charactersIn: "[]")).lowercased() == tail }) {
            return entry.value
        }
        return nil
    }

    // MARK: - Cleanup

    func clear() {
        registry.removeAll()
        counter = 0
    }

    // MARK: - Diagnostics

    var isEmpty: Bool { registry.isEmpty }

    // MARK: - Private

    private var base58Regex: NSRegularExpression? {
        // swiftlint:disable:next force_try
        try? NSRegularExpression(pattern: "[1-9A-HJ-NP-Za-km-z]{32,}")
    }
}
