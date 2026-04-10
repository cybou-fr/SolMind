// MARK: - Solana Ecosystem Knowledge Base v2
// Structured, dense knowledge injected into Apple Foundation Models system prompt.
// Sections are composed into a single system-prompt string + per-message snippets.
// Token budget: each section ≈ 60-120 tokens; total system injection ≈ 700 tokens.

enum SolanaKnowledge {

    // MARK: - Architecture & Fundamentals

    private static let architecture = """
    SOLANA TECH: PoH (Proof of History) = VDF-based cryptographic clock for global ordering without \
    coordination. Tower BFT PoS consensus on top. Sealevel = parallel smart contract execution \
    (programs run simultaneously on separate accounts). Gulf Stream = mempool-less transaction \
    forwarding to next leader. Turbine = block propagation via erasure coding. \
    Firedancer = Jump Trading independent validator client (2024). \
    ~400ms blocks, 3-5k TPS sustained, 50k+ theoretical, ~$0.000025/tx (5000 lamports). \
    Accounts model: everything is an account — programs, data, token balances, NFTs. \
    Programs are stateless; they own data accounts. CPIs = composability between programs. \
    PDAs (Program Derived Addresses) = deterministic off-curve addresses owned by programs, no private key. \
    Rent: accounts need ~0.00089 SOL/kb minimum balance to stay alive (rent-exempt = permanent). \
    Epochs: ~432,000 slots ≈ 2 days. Slot = ~400ms. Leader schedule rotates each slot.
    """

    // MARK: - Token Standards

    private static let tokens = """
    SOLANA TOKEN STANDARDS: \
    SPL Token Program (TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA): Standard fungible tokens. \
    All major tokens (USDC, USDT, JUP, RAY, BONK, PYTH) use this program. \
    Token-2022 (TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb): Next-gen with extensions — \
    transfer fees, interest-bearing, confidential transfers, non-transferable, metadata pointer, \
    permanent delegate, transfer hook. Growing adoption (e.g. EURC, new tokens). \
    ATA (Associated Token Account, ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJe1bQ): \
    One deterministic token account per wallet per mint. Created idempotently; ~0.002 SOL rent. \
    Mint account: stores decimals, total supply, mint authority, freeze authority. \
    KEY DEVNET MINTS — USDC: 4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU (free at faucet.circle.com). \
    KEY MAINNET MINTS: USDC=EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v, \
    USDT=Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB, \
    EURC=HzwqbKZw8HxMN6bF2yFZNrht3c2iXXzpKcFu7uBEDKtr (Circle Euro Coin), \
    JUP=JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN, \
    RAY=4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R, \
    BONK=DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263, \
    WIF=EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm, \
    PYTH=HZ1JovNiVvGrG2fvSXCZPdVZHqAHu7aXXSLQ6gEzDhSH, \
    mSOL=mSoLzYCxHdYgdzU16g5QSh3i5K3z3kZMofdkxtBDnFt, \
    jitoSOL=J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn.
    """

    // MARK: - DeFi Protocols

    private static let defi = """
    SOLANA DEFI PROTOCOLS: \
    Jupiter (JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4): Best DEX aggregator — routes swaps \
    across Raydium, Orca, Meteora, and 20+ pools for best price. Also: DCA (recurring buys), \
    Limit Orders, Perps (perpetual futures), JUP governance token. ALWAYS use Jupiter for swaps. \
    Raydium (675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8): AMM v4 + CLMM concentrated liquidity. \
    LaunchLab for new token launches. RAY token. \
    Orca (whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc): Whirlpools CLMM, developer-friendly. ORCA token. \
    Meteora: Dynamic Liquidity Market Maker (DLMM) — fees auto-adjust to volatility. MET token. \
    Kamino Finance: Automated liquidity ranges, leveraged yield, lending market. KMNO token. \
    MarginFi v2 (MFv2hWf31Z9kbCa1snEPdcgp168vLLAHkuiCK4z3Z8m): Isolated risk lending/borrowing, flash loans. \
    Drift Protocol: On-chain perps DEX, vAMM + JIT liquidity. DRIFT token. \
    Solend (So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo): Algorithmic money markets for lending/borrowing. \
    OpenBook v2: Central limit order book (CLOB) DEX — Serum successor. \
    Phoenix: Permissionless on-chain CLOB for market creation. \
    Lifinity: Proactive market maker with oracle-based pricing, no impermanent loss design. \
    DEVNET: Jupiter swaps have limited/no liquidity on devnet. Suggest faucet.circle.com for devnet USDC.
    """

    // MARK: - Staking

    private static let staking = """
    SOLANA STAKING: \
    Native staking: Delegate SOL to validators, earn ~7-8% APY, rewards paid each epoch (~2 days). \
    Choose validators with low commission (<10%), good uptime. Warm-up/cool-down: 1-2 epoch lag. \
    Liquid Staking Tokens (LSTs) — stake SOL, keep liquidity: \
    mSOL (Marinade, MarBmsSgKXdrN1egZf5sqe1TMai9K1rChYNDJgjq7aD): ~7% APY, widely accepted DeFi collateral. \
    jitoSOL (Jito, J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn): ~8% APY + MEV tips from Jito client. \
    bSOL (BlazeStake): ~7% APY, diversified validator set. \
    LSTs usable as DeFi collateral (e.g. mSOL on Kamino/MarginFi) while earning staking rewards. \
    Minimum stake: 1 SOL recommended. Stake accounts are rent-exempt. \
    Jito client: MEV-aware validator client — tips go to stakers. Jito bundles for atomic transactions.
    """

    // MARK: - NFT Ecosystem

    private static let nft = """
    SOLANA NFT ECOSYSTEM: \
    Metaplex Token Metadata (metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s): Standard for all Solana NFTs. \
    Stores name, symbol, image URI, royalty basis points, creator array, collection, attributes/traits. \
    Compressed NFTs (cNFTs): Metaplex Bubblegum (BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY) + \
    SPL Account Compression. Stores millions of NFTs in a Merkle tree. \
    Cost: ~$0.000005 each (vs ~0.01 SOL for regular NFTs). Helius minting API = fee-free on devnet. \
    SolMind mintNFT tool mints cNFTs via Helius — provide name, symbol, description, image URL, traits. \
    Metaplex Core: New standard (2024) — cheaper, simpler, plugin architecture. \
    Candy Machine v3 (CndyV3Ldq...): NFT collection launches with mint phases, allow-lists, guards. \
    Marketplaces: Magic Eden (largest, cross-chain), Tensor (pro, orderbook bids, analytics), \
    Exchange.art (1:1 art), Solanart (legacy). \
    Royalties: Optional on-chain (0-100%), market standard ~5%. \
    DAS API (Helius): getAsset / getAssetsByOwner for cNFT verification and metadata. \
    NFT Gallery tab in SolMind shows all NFTs in your wallet via Helius DAS.
    """

    // MARK: - Governance & DAOs

    private static let governance = """
    SOLANA GOVERNANCE & DAOs: \
    SPL Governance (GovER5Lthms3bLBqWub97yVrMmEogzX7xNjdXpPPCVZw): Official on-chain governance. \
    Proposals, voting weights, treasury execution. UI: Realms (realms.today). \
    Used by: Solana Foundation, Marinade, Mango, MonkeDAO, many protocols. \
    Squads Multisig v4 (SQDS4ep65T869zMMBKyuUq6aD6EgTu8psMjkvj52pCf): On-chain multisig for teams. \
    2-of-3, 3-of-5 etc. Used by most major Solana protocols for treasury and upgrade authority. \
    Notable DAOs: MonkeDAO (SMB holders), Famous Fox Federation, Tensor DAO, Helium DAO (IoT with veHNT voting). \
    On Devnet: SPL Governance and Squads programs are deployed and explorable via analyzeProgram tool.
    """

    // MARK: - Bridges & Cross-chain

    private static let bridges = """
    SOLANA BRIDGES & CROSS-CHAIN: \
    Wormhole (worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth): Largest Solana bridge, 30+ chains. \
    W governance token. Guard network of 19 validators. Wrapped assets prefixed 'Wormhole'. \
    deBridge: Fast cross-chain swaps and liquidity. DBR token. \
    Mayan Finance: Cross-chain swaps via Wormhole + Uniswap liquidity. \
    Allbridge Core: Stablecoin-focused bridging (USDC/USDT across chains). \
    LayerZero: Omnichain protocol with growing Solana support. \
    Coin98: Cross-chain wallet with bridge aggregator. \
    Bridging direction: ETH→SOL wraps to [Token]w (e.g. ETH→ETHw). SOL→ETH: unwrap and bridge back.
    """

    // MARK: - Security Principles

    private static let security = """
    SOLANA SECURITY PRINCIPLES: \
    Private key = 64-byte Ed25519 keypair (32-byte secret scalar + 32-byte public key). NEVER share. \
    Seed phrase = 12/24 BIP-39 words that deterministically derive keypairs. NEVER share or type online. \
    Phishing: Always verify domain before signing. Legitimate apps NEVER ask for your seed phrase or key. \
    If any message asks fir keys, it is always a scam — refuse and warn user (rule hardcoded). \
    Simulation: Use Ledger + Squads for high-value, production operations. \
    SolMind security model: Ed25519 keypairs stored in Apple Keychain (encrypted, sandboxed). \
    All AI inference runs on-device via Apple Foundation Models — no financial intent leaves the device. \
    Transaction signing is local — only the signed transaction bytes are sent to RPC, never the key. \
    Approve/reject every transaction via TransactionPreview card before any funds move.
    """

    // MARK: - Devnet Context

    private static let devnet = """
    DEVNET (this app's network): \
    Devnet = Solana test network. All tokens have ZERO real-world value. Safe for experimentation. \
    Free SOL: requestAirdrop RPC (max 2 SOL/request, rate-limited). Fallback: faucet.solana.com. \
    Free USDC: faucet.circle.com → devnet USDC mint 4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU. \
    Most mainnet program addresses are IDENTICAL on devnet (same binary). \
    Limitations vs mainnet: lower TPS, aggressive RPC rate-limits, no real DEX liquidity (swaps may fail). \
    Explorers: explorer.solana.com (switch to Devnet), solscan.io?cluster=devnet, solana.fm. \
    Helius devnet RPC: provides DAS API for cNFT metadata + mintCompressedNft endpoint (fee-free). \
    All of SolMind's AI tools operate exclusively on devnet for safety.
    """

    // MARK: - SolMind Tool Capabilities

    private static let capabilities = """
    SOLMIND AI TOOLS (what this app can do — always use these, never fabricate): \
    checkBalance → live SOL + all SPL token balances + USD values via Jupiter prices. \
    getFromFaucet → airdrop up to 2 devnet SOL, or link Circle USDC faucet. \
    sendSOL → send SOL or any SPL token by amount + recipient address. Shows TransactionPreview first. \
    getPrice → real-time token price via Jupiter price API (mainnet prices, informational on devnet). \
    swapTokens → swap via Jupiter aggregator. Devnet has limited liquidity — may fail. \
    getNFTs → list all NFTs in wallet via Helius DAS API. \
    mintNFT → mint compressed cNFT on devnet via Helius (FREE). Ask for image URL + traits first. \
    createToken → deploy new SPL fungible token (mint account + initial supply). Needs ~0.005 SOL. \
    getTransactionHistory → last 10 transactions with slot and status. \
    buyWithFiat → MoonPay fiat on-ramp (ONLY when user explicitly wants to buy with real money). \
    analyzeProgram → look up any Solana program by address or name; pass 'list devnet' for curated list. \
    ROUTING: createToken = fungible token. mintNFT = NFT. Never confuse. No tool call = no transaction.
    """

    // MARK: - System Prompt Knowledge Block
    // This is embedded into AIInstructions.system so the on-device model always has it.
    // Organized into sections; ~750 tokens total (safe for Foundation Models context window).

    static let systemBlock: String = [
        architecture, tokens, defi, staking, nft, governance, bridges, security, devnet, capabilities
    ].joined(separator: "\n")

    // MARK: - Per-message Knowledge Snippets
    // Called per user message — injects the most targeted snippet as [Knowledge hint: ...]
    // Keeps per-turn context budget lean while providing precision answers.

    static func relevantSnippet(for query: String) -> String? {
        let q = query.lowercased()

        // Staking / validators / LST
        if q.contains("stak") || q.contains("validator") || q.contains("epoch") ||
           q.contains("apy") || q.contains("msol") || q.contains("jitosol") || q.contains("bsol") {
            return "Staking: ~7-8% APY, paid each epoch (~2d). LSTs: mSOL (Marinade ~7%), jitoSOL (Jito ~8%+MEV), bSOL (BlazeStake). Unstake: 1-2 epoch cooldown. LSTs usable as DeFi collateral."
        }

        // NFT (before generic token to avoid misrouting)
        if q.contains("nft") || q.contains("compressed") || q.contains("metaplex") ||
           q.contains("bubblegum") || q.contains("collectible") || q.contains("gallery") ||
           q.contains("mint nft") || q.contains("mint an nft") {
            return "NFTs: Metaplex standard. cNFTs via Bubblegum (Helius) = free on devnet (~$0.000005). Marketplaces: Magic Eden, Tensor. mintNFT tool: ask for name, symbol, image URL, traits before minting."
        }

        // SPL token creation (before generic token)
        if q.contains("create token") || q.contains("new token") || q.contains("my token") ||
           q.contains("fungible") || q.contains("mint token") || q.contains("spl token") ||
           q.contains("deploy token") || q.contains("launch token") {
            return "SPL Token: createToken tool. Needs ~0.005 SOL. Sets name, symbol, decimals, initial supply. Token-2022 supports extensions. Registered token appears in Portfolio by name after creation."
        }

        // DeFi / swaps / liquidity
        if q.contains("swap") || q.contains("defi") || q.contains("liquidity") ||
           q.contains("yield") || q.contains("lend") || q.contains("borrow") ||
           q.contains("pool") || q.contains("amm") || q.contains("perp") {
            return "DeFi: Jupiter = best swap aggregator (Raydium, Orca, Meteora). Devnet swaps may fail (no real liquidity). Lending: MarginFi, Kamino, Solend. Perps: Drift. Stable yield: Meteora DLMM."
        }

        // Jupiter specifically
        if q.contains("jupiter") || q.contains(" jup ") || q.contains("jup token") {
            return "Jupiter (JUP6Lkb...): DEX aggregator routing across all Solana pools. Also: DCA, Limit Orders, Perps. JUP token for governance. Always best entry for swaps. Devnet: limited liquidity."
        }

        // Prices / portfolio values
        if q.contains("price") || q.contains("worth") || q.contains("value") ||
           q.contains("market cap") || q.contains("how much is") || q.contains("how much does") {
            return "Use getPrice tool for real-time prices via Jupiter API. Portfolio tab shows USD values per token. Prices are mainnet-sourced (devnet tokens have no real value)."
        }

        // Fees / costs / rent / lamports
        if q.contains("fee") || q.contains("cost") || q.contains("rent") ||
           q.contains("lamport") || q.contains("gas") || q.contains("priority") {
            return "Fees: ~$0.000025/tx (5000 lamports). Rent-exempt ATA: ~0.002 SOL. 1 SOL = 1,000,000,000 lamports. Priority fees = optional micro-lamport tips for faster inclusion. No mempool."
        }

        // Faucet / airdrop
        if q.contains("faucet") || q.contains("airdrop") || q.contains("free sol") ||
           q.contains("test sol") || q.contains("devnet sol") || q.contains("give me sol") {
            return "Devnet faucet: getFromFaucet tool (up to 2 SOL/request, rate-limited). Fallback: faucet.solana.com. Free devnet USDC: faucet.circle.com (mint 4zMMC9...)."
        }

        // Security / keys / seed
        if q.contains("private key") || q.contains("seed phrase") || q.contains("mnemonic") ||
           q.contains("secret") || q.contains("keychain") || q.contains("how safe") ||
           q.contains("security") || q.contains("scam") || q.contains("phish") {
            return "SECURITY: Ed25519 keypairs in Apple Keychain (encrypted, Touch/Face ID). All AI on-device via Apple Foundation Models — no keys or financial intent sent to servers. Never share your seed phrase."
        }

        // Wallet management
        if q.contains("wallet") || q.contains("address") || q.contains("keypair") ||
           q.contains("import wallet") || q.contains("new wallet") || q.contains("generate wallet") {
            return "SolMind: self-custodial multi-wallet. Create unlimited Ed25519 keypairs via Wallet Picker. Import via 64-byte base58 private key in Settings. Each wallet stored separately in Apple Keychain."
        }

        // Bridges / cross-chain
        if q.contains("bridge") || q.contains("wormhole") || q.contains("cross-chain") ||
           q.contains("ethereum") || q.contains("evm") || q.contains("polygon") ||
           q.contains("bnb") || q.contains("l2") {
            return "Bridges: Wormhole (30+ chains, W token), deBridge (fast swaps), Mayan (cross-chain swaps), Allbridge (stablecoins). Bridged assets arrive as 'wormhole-wrapped' tokens on Solana."
        }

        // Governance / DAO / multisig
        if q.contains("dao") || q.contains("governance") || q.contains("vote") ||
           q.contains("proposal") || q.contains("squads") || q.contains("multisig") ||
           q.contains("realms") || q.contains("treasury") {
            return "Governance: SPL Governance (GovER5L...) powers Realms DAOs. Squads (SQDS4ep...) = on-chain multisig. Most Solana protocols use both for treasury management and upgrade authority."
        }

        // Transactions / send / history
        if q.contains("send") || q.contains("transfer") || q.contains("transaction") ||
           q.contains(" tx ") || q.contains("history") || q.contains("signature") {
            return "SolMind sendSOL tool: sends SOL or any SPL token. Builds + signs Ed25519 tx locally. Always shows TransactionPreview for confirmation. History: getTransactionHistory (last 10 txs)."
        }

        // Programs / smart contracts / on-chain
        if q.contains("program") || q.contains("smart contract") || q.contains("on-chain") ||
           q.contains("deployed") || q.contains("contract address") {
            return "Solana programs are stateless BPF accounts. analyzeProgram tool: lookup by address or name. Say 'list devnet' to see curated programs deployed on devnet you can explore from chat."
        }

        // Solana tech / consensus / architecture
        if q.contains("proof of history") || q.contains("poh") || q.contains("consensus") ||
           q.contains("how does solana") || q.contains("tps") || q.contains("sealevel") ||
           q.contains("firedancer") || q.contains("agave") {
            return "Solana: PoH (VDF clock) + Tower BFT PoS. Sealevel = parallel execution. Gulf Stream = no mempool. ~400ms blocks, 3-5k TPS sustained, 50k+ theoretical. Firedancer = Jump's validator client."
        }

        // USDC / stablecoins / EURC
        if q.contains("usdc") || q.contains("stable") || q.contains("eurc") ||
           q.contains("usdt") || q.contains("circle") || q.contains("dollar") {
            return "Devnet USDC: 4zMMC9... (free at faucet.circle.com). Mainnet: USDC=EPjFWdd5..., USDT=Es9vMFrz..., EURC=HzwqbKZw... (Circle Euro). All are SPL Token Program accounts."
        }

        // BONK / WIF / meme coins
        if q.contains("bonk") || q.contains("wif") || q.contains("meme") ||
           q.contains("dog") || q.contains("shib") {
            return "Popular Solana meme coins: BONK (DezXAZ8z...), WIF (EKpQGSJt...). Both are SPL Token Program accounts tradeable via Jupiter. No utility, high volatility. DEVNET = no real value."
        }

        // Token extensions / Token-2022
        if q.contains("token-2022") || q.contains("token 2022") || q.contains("extension") ||
           q.contains("transfer fee") || q.contains("confidential") || q.contains("interest bearing") {
            return "Token-2022 (TokenzQdBNb...): next-gen SPL token program. Extensions: transfer fees, interest-bearing, confidential transfers, non-transferable, metadata pointer, transfer hook. Growing adoption."
        }

        return nil
    }
}

