// MARK: - Solana Ecosystem Knowledge Base
// systemBlock is a COMPACT routing reference (~200 tokens) injected into every session.
// Full knowledge sections are ONLY surfaced via relevantSnippet() on matching queries.
// This keeps the total system prompt well under the 4096-token Foundation Models limit.

enum SolanaKnowledge {

    // MARK: - System Prompt Knowledge Block (COMPACT — injected every session)

    static let systemBlock = """
    SOLANA/DEVNET FACTS: Network=devnet (test only, zero real value). 1 SOL=1e9 lamports. Tx fee≈$0.000025. \
    Free SOL: getFromFaucet (max 2/req). Free USDC: faucet.circle.com, devnet mint=4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU. \
    Mainnet mints: USDC=EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v, USDT=Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB, \
    EURC=HzwqbKZw8HxMN6bF2yFZNrht3c2iXXzpKcFu7uBEDKtr, JUP=JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN, \
    RAY=4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R, BONK=DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263, \
    mSOL=mSoLzYCxHdYgdzU16g5QSh3i5K3z3kZMofdkxtBDnFt. \
    TOOLS: getBalance, getFromFaucet, sendSOL, getPrice, swapTokens(Jupiter,devnet limited), \
    getNFTs, mintNFT(cNFT via Helius—ask image URL+traits first), createToken(SPL fungible ~0.005 SOL), \
    getTransactionHistory, buyWithFiat(real money only), analyzeProgram('list devnet' shows all programs). \
    ROUTING: createToken=fungible SPL. mintNFT=NFT. No tool call = no tx. Jupiter swaps fail on devnet.
    """

    // MARK: - Full Knowledge Sections (only used by relevantSnippet — NOT in system prompt)

    private static let architecture = """
    Solana: PoH (VDF clock) + Tower BFT PoS. Sealevel = parallel execution (separate accounts run simultaneously). \
    Gulf Stream = mempool-less forwarding. Turbine = erasure-coded block propagation. Firedancer = Jump's validator client. \
    ~400ms blocks, 3–5k TPS sustained, 50k+ theoretical. Accounts model: programs are stateless, own data accounts. \
    CPIs = composability. PDAs = deterministic off-curve addresses, no private key, owned by programs. \
    Rent: ~0.00089 SOL/kb to stay alive (rent-exempt = permanent). Epochs ≈ 432k slots ≈ 2 days. Leader rotates each slot.
    """

    private static let tokens = """
    SPL Token (TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA): standard fungible tokens (USDC, USDT, JUP, RAY, BONK, PYTH). \
    Token-2022 (TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb): extensions — transfer fees, interest-bearing, \
    confidential transfers, non-transferable, metadata pointer, transfer hook. EURC uses Token-2022. \
    ATA (ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJe1bQ): one deterministic token account per wallet per mint. ~0.002 SOL rent. \
    Devnet USDC: 4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU (faucet.circle.com). \
    WIF=EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm. jitoSOL=J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn. \
    PYTH=HZ1JovNiVvGrG2fvSXCZPdVZHqAHu7aXXSLQ6gEzDhSH.
    """

    private static let defi = """
    Jupiter (JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4): best DEX aggregator — routes across Raydium, Orca, Meteora, 20+ pools. \
    Also: DCA, Limit Orders, Perps. JUP governance token. ALWAYS best entry for swaps. Devnet: no real liquidity. \
    Raydium (675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8): AMM v4 + CLMM. RAY token. LaunchLab for new tokens. \
    Orca (whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc): Whirlpools CLMM. ORCA token. Developer-friendly. \
    Meteora: DLMM fees auto-adjust to volatility. Kamino: automated liquidity, leveraged yield, lending. \
    MarginFi v2: isolated risk lending, flash loans. Drift: on-chain perps vAMM+JIT. Solend: algorithmic money markets. \
    OpenBook v2: CLOB DEX (Serum successor). Phoenix: permissionless CLOB. Lifinity: oracle-based proactive MM.
    """

    private static let staking = """
    Native staking: delegate SOL to validators, ~7–8% APY, rewards per epoch (~2d). \
    Warm-up/cooldown: 1–2 epoch lag. Choose validators with <10% commission, good uptime. \
    LSTs (Liquid Staking Tokens): mSOL (Marinade ~7%), jitoSOL (Jito ~8%+MEV tips), bSOL (BlazeStake ~7%). \
    LSTs usable as DeFi collateral (Kamino, MarginFi) while earning rewards. Minimum stake: 1 SOL. \
    Jito client: MEV-aware validator, tips distributed to stakers. Jito bundles = atomic transactions.
    """

    private static let nft = """
    Metaplex Token Metadata (metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s): standard for all Solana NFTs. \
    Stores name, symbol, image URI, royalties, creators, collection, attributes. \
    Compressed NFTs (cNFTs): Bubblegum (BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY) + SPL Account Compression (Merkle tree). \
    Cost: ~$0.000005 (vs ~0.01 SOL regular). Helius minting API = fee-free on devnet. \
    mintNFT tool: always ask for name, symbol, description, image URL, traits before calling. \
    Metaplex Core (2024): cheaper, simpler, plugin architecture. Candy Machine v3: collection launches. \
    Marketplaces: Magic Eden (largest, cross-chain), Tensor (pro/orderbook), Exchange.art (1:1 art). \
    DAS API: getAsset / getAssetsByOwner for cNFT verification. NFT Gallery tab uses Helius DAS.
    """

    private static let governance = """
    SPL Governance (GovER5Lthms3bLBqWub97yVrMmEogzX7xNjdXpPPCVZw): official on-chain governance. \
    Proposals, voting weights, treasury execution. UI: realms.today. Used by Solana Foundation, Marinade, Mango, MonkeDAO. \
    Squads Multisig v4 (SQDS4ep65T869zMMBKyuUq6aD6EgTu8psMjkvj52pCf): on-chain multisig (2-of-3, 3-of-5 etc). \
    Used by most protocols for treasury + upgrade authority. Both deployed on devnet — explore via analyzeProgram.
    """

    private static let bridges = """
    Wormhole (worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth): largest Solana bridge, 30+ chains, W governance token. \
    deBridge: fast cross-chain swaps, DBR token. Mayan: cross-chain swaps via Wormhole+Uniswap liquidity. \
    Allbridge Core: stablecoin bridging (USDC/USDT cross-chain). LayerZero: growing Solana support. \
    Bridged assets tagged with source: 'Wormhole-wrapped ETH' etc. SOL→ETH: unwrap then bridge back.
    """

    private static let security = """
    Ed25519 keypair: 32-byte secret scalar + 32-byte pubkey. NEVER share. Seed phrase (12/24 BIP-39 words) = master key. \
    Phishing: verify domain before signing. No app ever needs your seed phrase or private key — always a scam. \
    SolMind: keys in Apple Keychain (encrypted, sandboxed, Touch/Face ID). All AI inference on-device (Foundation Models). \
    No keys or financial intent leave the device. Only signed tx bytes sent to RPC. TransactionPreview before every tx.
    """

    // MARK: - Per-message Knowledge Snippets
    // Injected as [Knowledge hint:...] in buildContextualPrompt when the query matches.
    // These are the ONLY place detailed knowledge appears — NOT in the system prompt.

    static func relevantSnippet(for query: String) -> String? {
        let q = query.lowercased()

        if q.contains("stak") || q.contains("validator") || q.contains("epoch") ||
           q.contains("apy") || q.contains("msol") || q.contains("jitosol") || q.contains("bsol") ||
           q.contains("liquid staking") || q.contains("lst") {
            return staking
        }
        if q.contains("nft") || q.contains("compressed") || q.contains("metaplex") ||
           q.contains("bubblegum") || q.contains("collectible") || q.contains("gallery") ||
           q.contains("mint nft") || q.contains("mint an nft") {
            return nft
        }
        if q.contains("create token") || q.contains("new token") || q.contains("my token") ||
           q.contains("fungible") || q.contains("spl token") || q.contains("deploy token") ||
           q.contains("launch token") || q.contains("token-2022") || q.contains("extension") {
            return tokens
        }
        if q.contains("swap") || q.contains("defi") || q.contains("liquidity") ||
           q.contains("yield") || q.contains("lend") || q.contains("borrow") || q.contains("pool") ||
           q.contains("amm") || q.contains("perp") || q.contains("jupiter") {
            return defi
        }
        if q.contains("bridge") || q.contains("wormhole") || q.contains("cross-chain") ||
           q.contains("ethereum") || q.contains("evm") || q.contains("polygon") || q.contains("l2") {
            return bridges
        }
        if q.contains("dao") || q.contains("governance") || q.contains("vote") ||
           q.contains("squads") || q.contains("multisig") || q.contains("realms") || q.contains("proposal") {
            return governance
        }
        if q.contains("private key") || q.contains("seed phrase") || q.contains("mnemonic") ||
           q.contains("security") || q.contains("scam") || q.contains("phish") || q.contains("keychain") {
            return security
        }
        if q.contains("proof of history") || q.contains("poh") || q.contains("consensus") ||
           q.contains("how does solana") || q.contains("tps") || q.contains("sealevel") ||
           q.contains("firedancer") || q.contains("parallel") || q.contains("architecture") {
            return architecture
        }
        return nil
    }
}

