import Foundation

// MARK: - Query Intent Classification
// Pre-model gate — classifies queries BEFORE any Foundation Models inference.
// Enables direct-answer bypasses (balance, price, FAQ) and lazy tool loading.

// MARK: - QueryIntent

enum QueryIntent: Equatable {
    /// Static FAQ lookup — zero-latency, no FM inference.
    case faqAnswer
    /// Format response directly from WalletViewModel — no FM needed.
    case directBalance
    /// Fetch from PriceService cache — no FM needed.
    case directPrice(symbol: String?)
    /// FM with ephemeral no-tool session — saves ~495 context tokens vs full pipeline.
    case directKnowledge
    /// FM required + full tool set + mandatory fresh session (transaction safety).
    case toolTransaction
    /// FM required + core tool set + session continuity eligible.
    case generalChat

    /// When true, always create a fresh LanguageModelSession (transaction safety).
    var requiresFreshSession: Bool {
        if case .toolTransaction = self { return true }
        return false
    }

    /// When true, Foundation Models inference is needed.
    var requiresModelInference: Bool {
        switch self {
        case .generalChat, .directKnowledge, .toolTransaction: return true
        case .faqAnswer, .directBalance, .directPrice:          return false
        }
    }

    /// When true, inject full wallet address + balances + network stats into the prompt.
    var needsWalletContext: Bool {
        switch self {
        case .toolTransaction, .generalChat: return true
        default:                             return false
        }
    }
}

// MARK: - Classifier

enum IntentClassifier {

    static func classify(_ query: String) -> QueryIntent {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)

        // 1. Transaction intents — checked first because some verbs (e.g. "send") appear
        //    in knowledge phrases ("send me an explanation"). Transaction verbs are anchored
        //    to known crypto objects to avoid false positives.
        if matchesTransaction(q) { return .toolTransaction }

        // 2. Balance shortcut — exact phrases only (avoids catching "balance of DeFi")
        if matchesBalance(q) { return .directBalance }

        // 3. Price shortcut
        if matchesPrice(q) { return .directPrice(symbol: extractSymbol(q)) }

        // 4. Pure ecosystem knowledge — explanatory verb + Solana topic required
        if matchesKnowledge(q) { return .directKnowledge }

        // 5. Default — full FM pipeline with core tools
        return .generalChat
    }

    // MARK: - Transaction Detection

    private static func matchesTransaction(_ q: String) -> Bool {
        // Faucet / airdrop — "get", "give me", "send me", "drop", "need", "want" + SOL variants
        let faucetVerbs = ["get devnet sol", "get free sol", "free devnet sol",
                           "give me sol", "give me devnet", "give me free",
                           "send me sol", "send me devnet", "send me free",
                           "drop me sol", "drop some sol", "i need sol", "need devnet sol",
                           "want some sol", "want devnet sol"]
        if q.contains("faucet") || q.contains("airdrop") || q == "get sol" {
            return true
        }
        if faucetVerbs.contains(where: { q.contains($0) }) { return true }

        // Send / transfer — verb must be followed by crypto context
        let sendVerbs = ["send ", "transfer ", "pay "]
        let cryptoObjects = ["sol", "usdc", "usdt", "token", "to "]
        if sendVerbs.contains(where: { q.contains($0) }) &&
           cryptoObjects.contains(where: { q.contains($0) }) { return true }

        // Swap — verb + token pair
        if (q.contains("swap") || q.contains("exchange ") || q.contains("trade ")) &&
           (q.contains("sol") || q.contains("usdc") || q.contains("token") || q.contains(" for ")) { return true }

        // NFT minting
        if (q.contains("mint") && q.contains("nft")) ||
           q.contains("create nft") || q.contains("mint nft") { return true }

        // Token creation
        if q.contains("create token") || q.contains("create a token") ||
           q.contains("new token") || q.contains("deploy token") ||
           q.contains("launch token") || q.contains("make a token") { return true }

        // On-ramp (real money purchase)
        if (q.contains("buy") || q.contains("purchase")) &&
           (q.contains("sol") || q.contains("crypto") || q.contains("real money") ||
            q.contains("fiat") || q.contains("moonpay")) { return true }

        // Program analysis
        if q.contains("analyze") || q.contains("analyse") ||
           q.contains("list devnet") || q.contains("list programs") ||
           q.contains("show programs") { return true }

        // Transaction history
        if q.contains("transaction history") || q.contains("recent transactions") ||
           q.contains("my transactions") || q.contains("show tx") ||
           q.contains("tx history") || q.contains("transaction list") { return true }

        // NFT gallery / portfolio viewing — requires NFT tool call
        if q.contains("my nft") || q.contains("show nft") || q.contains("view nft") ||
           q.contains("nft gallery") || q.contains("my collection") ||
           q.contains("see my nft") || q.contains("list my nft") { return true }

        return false
    }

    // MARK: - Balance Detection

    private static func matchesBalance(_ q: String) -> Bool {
        let phrases = [
            "my balance", "check balance", "show balance", "view balance",
            "how much sol", "how much do i have", "how many sol",
            "what's my balance", "what is my balance", "my sol balance",
            "my wallet balance", "current balance", "wallet balance",
            "my portfolio", "my tokens", "token balance", "portfolio balance"
        ]
        return phrases.contains { q.contains($0) }
    }

    // MARK: - Price Detection

    private static func matchesPrice(_ q: String) -> Bool {
        let phrases = [
            "price of", "price for", "sol price", "what's the price",
            "what is the price", "current price", "how much is sol",
            "sol in usd", "sol worth", "worth in usd", "sol usd",
            "solana price", "check price", "token price"
        ]
        return phrases.contains { q.contains($0) }
    }

    private static func extractSymbol(_ q: String) -> String? {
        let tokens = ["sol", "usdc", "usdt", "btc", "eth", "jup",
                      "ray", "bonk", "wif", "msol", "jitosol", "bsol", "pyth", "eurc"]
        return tokens.first(where: { q.contains($0) })?.uppercased()
    }

    // MARK: - Knowledge Detection

    private static func matchesKnowledge(_ q: String) -> Bool {
        // Require an explanatory lead phrase or structural question word
        let knowledgeLeads = [
            "what is", "what are", "what's", "how does", "how do", "how is",
            "explain", "tell me about", "describe", "why does", "why is",
            "what does", "can you explain", "help me understand",
            "learn about", "what are the", "give me info", "how works",
            "what's the difference"
        ]
        let startsKnowledge = ["what ", "how ", "why ", "tell ", "explain ", "describe "]

        let hasLead  = knowledgeLeads.contains { q.contains($0) }
        let hasStart = startsKnowledge.contains { q.hasPrefix($0) }
        guard hasLead || hasStart else { return false }

        // Must involve a known Solana / DeFi concept
        let topics = [
            "solana", "devnet", "mainnet", "spl", "token",
            "nft", "staking", "stake", "validator", "epoch", "lst",
            "defi", "jupiter", "raydium", "orca", "marinade", "jito",
            "proof of history", "poh", "sealevel", "firedancer",
            "swap", "liquidity", "amm", "dex", "pool", "perp",
            "bridge", "wormhole", "cross-chain",
            "governance", "dao", "multisig", "squads",
            "seed phrase", "private key", "mnemonic", "keychain",
            "compressed nft", "metaplex", "bubblegum", "magic eden",
            "wallet", "fee", "lamport", "rent", "pda", "cpi",
            "token-2022", "helius", "airdrop",
            "consensus", "bft", "block time", "tps", "transaction",
            // New: Solana architecture layers
            "gulf stream", "turbine", "tower bft", "tower bft", "erasure",
            // New: protocols & DEXes
            "kamino", "marginfi", "openbook", "phoenix", "marinade native",
            "compressed", "cnft", "bubblegum",
            // New: use-case / how-to leads
            "what can i do", "how do i use", "how to use solmind"
        ]
        return topics.contains { q.contains($0) }
    }
}
