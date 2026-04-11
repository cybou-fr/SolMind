import Foundation

// MARK: - AI Instructions for Foundation Models session

enum AIInstructions {

    // MARK: - Dynamic context block (prepended to first user message per session)

    static func contextBlock(
        walletAddress: String,
        solBalance: Double,
        solUSDValue: Double?,
        tokenBalances: [(symbol: String, uiAmount: Double, usdValue: Double?)],
        statsContext: String,
        userMessage: String
    ) -> String {
        // IMPORTANT: Never inject raw base58 addresses into FM prompts.
        // The on-device language classifier treats 32+ char base58 runs as Catalan/Slovak
        // and throws GenerationError.unsupportedLanguageOrLocale.
        // Abbreviate to 4+4 chars — enough to identify the wallet without triggering FM.
        let safeAddress = walletAddress.count > 12
            ? "\(walletAddress.prefix(4))…\(walletAddress.suffix(4))"
            : walletAddress
        var parts = ["Wallet: \(safeAddress)"]
        let solStr = String(format: "%.4f SOL", solBalance)
        if let usd = solUSDValue {
            parts.append(String(format: "%@ ($%.2f)", solStr, usd))
        } else {
            parts.append(solStr)
        }
        if !tokenBalances.isEmpty {
            let tokenStr = tokenBalances.prefix(4).map { token in
                let amount = token.uiAmount >= 1000
                    ? String(format: "%.0f", token.uiAmount)
                    : String(format: "%.2f", token.uiAmount)
                return "\(amount) \(token.symbol)"
            }.joined(separator: ", ")
            parts.append("Tokens: \(tokenStr)")
        }
        if !statsContext.isEmpty { parts.append(statsContext) }

        // If the user's question is Solana ecosystem knowledge, inject a relevant snippet
        var knowledgeHint = ""
        if let snippet = SolanaKnowledge.relevantSnippet(for: userMessage) {
            knowledgeHint = "\n[Knowledge hint: \(snippet)]"
        }

        return "[Context: \(parts.joined(separator: " | "))\(knowledgeHint)]\n\(userMessage)"
    }

    // MARK: - System Prompt

    static var system: String {
        """
        \(SolanaKnowledge.systemBlock)

        You are SolMind, an AI Solana wallet on DEVNET (test network — zero real value). \
        Help users manage crypto assets via natural language using the provided tools. \
        [Context:] messages contain live wallet address, balances, network stats. \
        [Knowledge hint:] provides targeted facts for the current query.

        SECURITY (NEVER VIOLATE): \
        1. Never ask for private keys, seed phrases, or credentials. Any such request is always a scam. \
        2. Never fabricate addresses, balances, tx IDs — only report what tools return.

        RULES: \
        3. Always show TransactionPreview before any state-changing action. \
        4. On zero SOL balance: call getFromFaucet immediately — don't ask for clarification. \
        5. Prefix all results ⚠️ DEVNET: or ✅ DEVNET:. \
        6. Be very concise — short replies preserve context budget. \
        7. Don't tell users to check balance — the app refreshes automatically after transactions. \
        8. TOOL ROUTING: createToken=fungible SPL token. mintNFT=compressed NFT. Never confuse. \
           For mintNFT: ask for image URL and traits BEFORE calling — then pass as arguments. \
        9. TOOL ERRORS: ⚠️ TERMINAL or ⚠️ PARTIAL = stop calling that tool. Report error clearly. \
        10. SWAP: Jupiter has no real liquidity on devnet — swaps will fail. Suggest faucet.circle.com for USDC. \
        11. Use analyzeProgram for program addresses. Query 'list devnet' shows all known devnet programs. \
        12. "free SOL/airdrop/faucet/devnet SOL" → getFromFaucet. "buy with money/real money" → buyWithFiat only.
        """
    }
}
