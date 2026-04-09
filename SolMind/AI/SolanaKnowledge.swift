// MARK: - Solana Ecosystem Knowledge Base
// Injected into the AI system prompt to give deep Solana context.
// Kept concise to preserve context-window budget (~4096 tokens total).

enum SolanaKnowledge {

    /// Core knowledge — always included in system prompt
    static let core = """
    SOLANA ECOSYSTEM (devnet = test network, no real value):
    TECH: PoH (Proof of History) cryptographic clock + Tower BFT PoS. ~400ms blocks, ~3k-5k TPS sustained, \
    ~$0.000025/tx fee (50% burned). Accounts model — everything (programs, tokens, NFTs) is an account. \
    Rent: keep ~0.002 SOL in account to stay rent-exempt. Epochs ~432k slots (~2 days).
    KEY PROGRAMS: System (SOL transfers), Token Program (SPL tokens), Token-2022 (next-gen with extensions: \
    transfer-hooks, confidential transfers, metadata), ATA Program (deterministic token accounts), \
    Metaplex (NFT standard), Bubblegum (compressed NFTs — millions of NFTs for ~$0.000005 each).
    DEFI: Jupiter (best DEX aggregator, routing across all pools; also perps, DCA, JUP token), \
    Raydium (AMM+CLMM, Launchpad), Orca (Whirlpools CLMM), Kamino (leveraged liquidity, lending, KMNO), \
    MarginFi (lending/borrow), Drift (perps DEX), Meteora (DLMM dynamic pools), \
    Jito (MEV-aware client, jitoSOL liquid staking).
    STAKING: Native ~7-8% APY, rewards paid each epoch. Liquid staking: Marinade (mSOL), \
    Jito (jitoSOL +MEV), BlazeStake (bSOL). Unstake takes ~1-2 epochs.
    NFTs: Metaplex standard. Marketplaces: Magic Eden (largest), Tensor (pro/orderbook). \
    Compressed NFTs (cNFTs) via Helius are free to mint on devnet. Regular NFTs need ~0.01 SOL.
    TOKENS: USDC (Circle, most-used stablecoin), USDT, JUP, RAY, ORCA, BONK, WIF, JTO, W (Wormhole), PYTH.
    WALLETS: Phantom (most popular, multi-chain), Backpack (xNFT), Solflare (staking-focused), Ledger (hardware).
    BRIDGES: Wormhole (30+ chains), deBridge, Allbridge.
    DEVTOOLS: Anchor (Rust framework), web3.js, Helius/QuickNode/Alchemy (premium RPCs).
    """

    /// Returns the most relevant knowledge snippet for a given user query
    static func relevantSnippet(for query: String) -> String? {
        let q = query.lowercased()
        if q.contains("stak") || q.contains("validator") || q.contains("epoch") || q.contains("apy") {
            return "Staking: ~7-8% APY, paid each epoch (~2 days). Liquid staking: mSOL (Marinade), jitoSOL (Jito+MEV), bSOL (BlazeStake). Unstaking: 1-2 epochs cooldown."
        }
        if q.contains("defi") || q.contains("swap") || q.contains("liquidity") || q.contains("yield") || q.contains("lend") {
            return "Top DeFi: Jupiter (swap aggregator), Raydium+Orca (AMMs), Kamino+MarginFi (lending), Drift (perps), Meteora (dynamic pools), Jito (MEV). Jupiter is always the best entry point for swaps."
        }
        // SPL token check before NFT — "create token", "mint tokens", "spl" must not trigger NFT advice
        if q.contains("token") || q.contains("spl") || q.contains("create coin") || q.contains("fungible") {
            return "SPL Token Program creates fungible tokens. Use createToken tool for new tokens. Token-2022 adds extensions. USDC is the most-used stablecoin on Solana."
        }
        // NFT check — does NOT include generic "mint" to avoid misrouting token-mint requests
        if q.contains("nft") || q.contains("compressed") || q.contains("metaplex") || q.contains("bubblegum") || q.contains("collectible") {
            return "NFTs use Metaplex standard. Magic Eden is the largest marketplace; Tensor is for pro traders. Compressed NFTs (cNFTs) cost ~$0.000005 each via Helius Bubblegum. Use mintNFT tool."
        }
        if q.contains("fee") || q.contains("cost") || q.contains("rent") || q.contains("lamport") {
            return "Fees: ~$0.000025/tx (5000 lamports). Rent-exempt: ~0.002 SOL for small accounts. Creating ATA: ~0.002 SOL. Priority fees are optional micro-lamport tips."
        }
        if q.contains("wallet") || q.contains("phantom") || q.contains("backpack") {
            return "Wallets: Phantom (best UX, multi-chain), Backpack (xNFTs), Solflare (best for staking), Ledger (hardware security)."
        }
        if q.contains("bridge") || q.contains("wormhole") || q.contains("cross-chain") || q.contains("ethereum") {
            return "Bridges: Wormhole (largest, 30+ chains), deBridge (fast), Allbridge (stablecoins). Wormhole wraps assets as 'wormhole-wrapped' tokens."
        }
        if q.contains("proof of history") || q.contains("poh") || q.contains("consensus") || q.contains("how does solana") {
            return "Solana uses Proof of History (PoH): a VDF creating a cryptographic clock so validators agree on time without communication. Tower BFT is the PoS consensus on top. Result: ~400ms blocks, parallel execution (Sealevel), no mempool (Gulf Stream)."
        }
        return nil
    }
}
