import Foundation

// MARK: - Contextual Suggestion Engine
// Generates follow-up suggestion chips shown after each AI response.

struct SuggestionEngine {

    // MARK: - Public API

    static func suggestions(
        for aiResponse: String,
        userMessage: String,
        walletHasBalance: Bool
    ) -> [String] {
        let r = aiResponse.lowercased()
        let u = userMessage.lowercased()

        // Empty wallet → guide to faucet
        if r.contains("empty wallet") || r.contains("0.000000 sol") || r.contains("0 sol") {
            return ["Get free devnet SOL", "What is devnet?", "What's the SOL price?"]
        }

        // Successful transaction
        if (r.contains("✅") && r.contains("signature")) || r.contains("transaction sent") || r.contains("swap executed") {
            return ["Check my new balance", "View transaction history", "What's the SOL price?", "Send more SOL"]
        }

        // Balance query
        if u.contains("balance") || u.contains("how much") || r.contains("sol balance") {
            if walletHasBalance {
                return ["What's the SOL price?", "Send SOL to someone", "Swap SOL for USDC", "Show my transactions"]
            }
            return ["Get free devnet SOL", "What is devnet?", "What's the SOL price?"]
        }

        // Price query
        if u.contains("price") || u.contains("worth") || u.contains("usd") || r.contains("price:") || r.contains("$") && r.contains("sol") {
            return ["Check my balance", "Swap SOL for USDC", "Tell me about DeFi on Solana", "What is staking?"]
        }

        // Swap topic
        if u.contains("swap") || r.contains("jupiter") || r.contains("swap") {
            return ["Check my token balances", "What tokens can I swap?", "Tell me about Jupiter DEX", "Swap back to SOL"]
        }

        // NFT topic
        if u.contains("nft") || r.contains("nft") || u.contains("mint") || r.contains("compressed nft") {
            return ["View my NFT gallery", "Mint another NFT", "What are compressed NFTs?", "Tell me about Magic Eden"]
        }

        // Token creation
        if u.contains("create token") || u.contains("new token") || r.contains("token created") || r.contains("spl token") {
            return ["Check my token balance", "Send tokens to someone", "What is Token-2022?", "Tell me about SPL tokens"]
        }

        // Faucet / airdrop
        if u.contains("faucet") || u.contains("airdrop") || r.contains("airdrop") || r.contains("faucet") {
            return ["Check my balance", "Send SOL to a friend", "Swap SOL for USDC", "What is devnet?"]
        }

        // Transaction history
        if u.contains("history") || u.contains("transactions") || r.contains("recent transactions") {
            return ["Check my balance", "Send SOL", "Swap tokens", "View in explorer"]
        }

        // Staking / DeFi knowledge
        if u.contains("stak") || r.contains("marinade") || r.contains("jito") || r.contains("epoch") {
            return ["How do I stake SOL?", "What is liquid staking?", "What's my balance?", "Tell me about Jito"]
        }

        // Ecosystem knowledge questions
        if u.contains("what is") || u.contains("how does") || u.contains("explain") || u.contains("tell me about") {
            return ["What is DeFi on Solana?", "How does Proof of History work?", "What are the best wallets?", "What is Jupiter?"]
        }

        // Error / failure
        if r.contains("failed") || r.contains("error") || r.contains("could not") || r.contains("❌") {
            return ["Try again", "Check my balance", "Get devnet SOL from faucet", "What went wrong?"]
        }

        // On-ramp / buy
        if u.contains("buy") || u.contains("fiat") || u.contains("moonpay") || r.contains("moonpay") {
            return ["Check my balance", "What's the SOL price?", "What is devnet?", "Swap SOL for USDC"]
        }

        // Default — always useful starting points
        return ["What's my balance?", "What's the SOL price?", "Show my transactions", "Tell me about Solana DeFi"]
    }
}
