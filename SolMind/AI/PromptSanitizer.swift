import Foundation

// MARK: - Prompt Sanitizer
//
// Foundation Models' on-device language classifier runs on every prompt and rejects
// input it classifies as an unsupported locale, throwing:
//   GenerationError.unsupportedLanguageOrLocale
//
// Known triggers in Solana wallets:
//   (A) Base58 wallet addresses / tx hashes   ≥32 consecutive base58 chars
//       → classified as Catalan, Slovak, or similar by the classifier
//   (B) Any other ≥41-char non-space token     (base64 blobs, hex hashes, etc.)
//   (C) Private-use Unicode / control characters
//   (D) System locale mismatch                 (unrelated to prompt — must fix in Settings)
//
// This sanitizer handles A-C proactively, before any call to the FM framework.
// Case D is detected by the retry logic in ChatViewModel after proactive sanitization fails.

enum PromptSanitizer {

    // MARK: - Compiled regexes (created once, reused on every call)

    /// Base58 alphabet (Bitcoin/Solana): digits 1-9 + mixed-case A-Z/a-z excluding 0OIl.
    /// Matches clusters ≥32 chars — covers all Solana addresses (44 chars) and tx IDs (88 chars).
    private static let base58Regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[1-9A-HJ-NP-Za-km-z]{32,}")
    }()

    /// Matches any non-whitespace run ≥41 chars that wasn't already handled by base58Regex
    /// (e.g. base64 strings, hex hashes, JWT tokens).
    private static let longTokenRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "\\S{41,}")
    }()

    // MARK: - Public API

    /// Returns a sanitized copy of `input` safe for submission to Foundation Models.
    ///
    /// - Replaces base58 address/hash clusters with `[address]`
    /// - Replaces other very-long tokens with `[data]`
    /// - Strips private-use Unicode and non-printable control characters
    ///
    /// The returned string is always coherent English text so the AI context remains intact.
    /// The `wasModified` flag lets callers distinguish content-triggered errors from system ones.
    static func sanitize(_ input: String) -> (text: String, wasModified: Bool) {
        var result = input
        var modified = false

        // ── Pass 1: Base58 addresses / transaction hashes ─────────────────────────────────
        let range1 = NSRange(result.startIndex..., in: result)
        if base58Regex.firstMatch(in: result, range: range1) != nil {
            result = base58Regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "[address]"
            )
            modified = true
        }

        // ── Pass 2: Any remaining ≥41-char non-space token ────────────────────────────────
        let range2 = NSRange(result.startIndex..., in: result)
        if longTokenRegex.firstMatch(in: result, range: range2) != nil {
            result = longTokenRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "[data]"
            )
            modified = true
        }

        // ── Pass 3: Strip private-use Unicode & non-printable control characters ──────────
        // Allow: printable ASCII, tab (0x09), LF (0x0A), CR (0x0D), Latin supplements,
        //        extended Latin, common punctuation, emoji (U+1F300–U+1FAFF).
        // Strip: C0/C1 control chars, private-use area (U+E000–U+F8FF), specials (U+FFF0+).
        let filtered = result.unicodeScalars.filter { s in
            let v = s.value
            if v < 0x09 { return false }                        // C0 control (below TAB)
            if v == 0x0B || v == 0x0C { return false }          // VT, FF
            if v > 0x0D && v < 0x20 { return false }            // remaining C0
            if v >= 0x7F && v <= 0x9F { return false }          // DEL + C1 control
            if v >= 0xE000 && v <= 0xF8FF { return false }      // private-use area
            if v >= 0xFFF0 { return false }                      // specials block & beyond
            return true
        }
        let filteredStr = String(String.UnicodeScalarView(filtered))
        if filteredStr != result {
            result = filteredStr
            modified = true
        }

        return (result, modified)
    }

    // MARK: - Address Abbreviation Helper

    /// Abbreviates a base58 address to a safe short form for display in tool results and prompts.
    ///
    /// Full 32–44 char base58 strings trigger Foundation Models' language classifier (detected as
    /// Catalan, Croatian, or other languages). Truncating to ≤13 chars stays well below the
    /// detection threshold while keeping the address recognisable.
    ///
    /// Default format: `1Abc2Def…GHij` (8 prefix + … + 4 suffix = 13 chars)
    static func abbreviateBase58(_ address: String, prefix: Int = 8, suffix: Int = 4) -> String {
        let threshold = prefix + suffix + 1   // need at least one char to abbreviate
        guard address.count > threshold else { return address }
        return "\(address.prefix(prefix))…\(address.suffix(suffix))"
    }

    /// Returns `true` if `input` contains patterns known to trigger
    /// `GenerationError.unsupportedLanguageOrLocale` on Foundation Models.
    ///
    /// Use this **after** an error occurs to decide whether it was content-triggered
    /// (user pasted an address) vs. system-level (locale misconfiguration).
    static func containsTriggers(_ input: String) -> Bool {
        let r = NSRange(input.startIndex..., in: input)
        if base58Regex.firstMatch(in: input, range: r) != nil { return true }
        if longTokenRegex.firstMatch(in: input, range: r) != nil { return true }
        return false
    }
}
