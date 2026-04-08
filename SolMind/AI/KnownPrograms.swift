import Foundation

// MARK: - Known Solana Programs & Accounts Registry
// A curated map of important program addresses to human-readable descriptions.
// Used by AnalyzeProgramTool for instant, offline lookups.

struct ProgramInfo {
    let address: String
    let name: String
    let description: String
    let category: String   // System | Token | NFT | DeFi | Staking | Governance | Bridge
    let website: String?
}

enum KnownPrograms {

    // MARK: - Registry

    static let all: [String: ProgramInfo] = {
        var d: [String: ProgramInfo] = [:]
        for p in list { d[p.address] = p }
        return d
    }()

    // MARK: - Lookup

    static func info(for address: String) -> ProgramInfo? {
        all[address]
    }

    /// Case-insensitive search by name or keyword in description.
    static func search(name: String) -> [ProgramInfo] {
        let q = name.lowercased()
        return list.filter {
            $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    // MARK: - Program List

    private static let list: [ProgramInfo] = [

        // ── Core / System ─────────────────────────────────────────────────────

        .init(address: "11111111111111111111111111111111",
              name: "System Program",
              description: "Solana's native system program. Handles SOL transfers, account creation, nonce accounts, and program deployment.",
              category: "System", website: nil),

        .init(address: "ComputeBudget111111111111111111111111111111",
              name: "Compute Budget Program",
              description: "Set compute unit limits and priority fees (micro-lamports per CU) to prioritise transactions during network congestion.",
              category: "System", website: nil),

        .init(address: "Stake11111111111111111111111111111111111111",
              name: "Stake Program",
              description: "Solana's native staking program. Delegate SOL to validators to earn staking rewards (~6–7% APY).",
              category: "Staking", website: nil),

        .init(address: "Vote111111111111111111111111111111111111111",
              name: "Vote Program",
              description: "Solana's native validator vote program. Validators submit block votes through this program to reach consensus.",
              category: "System", website: nil),

        .init(address: "BPFLoaderUpgradeab1e11111111111111111111111",
              name: "BPF Upgradeable Loader",
              description: "Program loader for upgradeable Solana smart contracts. Manages program data accounts and upgrade authority.",
              category: "System", website: nil),

        .init(address: "NativeLoader1111111111111111111111111111111",
              name: "Native Loader",
              description: "Loads Solana's built-in native programs (System, Vote, Stake, etc.).",
              category: "System", website: nil),

        // ── Token Programs ────────────────────────────────────────────────────

        .init(address: "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
              name: "SPL Token Program",
              description: "The standard Solana fungible token program (Token v1). Manages all SPL tokens including USDC, USDT, and every custom token.",
              category: "Token", website: "https://spl.solana.com/token"),

        .init(address: "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb",
              name: "Token-2022 (Token Extensions)",
              description: "Next-generation token program with extensions: transfer fees, confidential transfers, interest-bearing tokens, non-transferable tokens, and more.",
              category: "Token", website: "https://spl.solana.com/token-2022"),

        .init(address: "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJe1bQ",
              name: "Associated Token Account Program",
              description: "Creates and manages Associated Token Accounts (ATAs) — the standard per-user token account for each SPL token mint.",
              category: "Token", website: nil),

        // ── NFT / Metaplex ────────────────────────────────────────────────────

        .init(address: "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s",
              name: "Metaplex Token Metadata",
              description: "The standard NFT metadata program. Stores name, symbol, image URI, royalties, and creator info for virtually all Solana NFTs.",
              category: "NFT", website: "https://metaplex.com"),

        .init(address: "BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY",
              name: "Bubblegum (Compressed NFTs)",
              description: "Metaplex Bubblegum for minting and transferring compressed NFTs (cNFTs). Minting costs fractions of a cent — used by Helius and Magic Eden.",
              category: "NFT", website: "https://developers.metaplex.com/bubblegum"),

        .init(address: "CndyV3LdqHUfDLmE5naZjVN8rBZz4tqhdefbAnjHG3JR",
              name: "Candy Machine v3",
              description: "Metaplex Candy Machine for NFT collection launches. Manages mint phases, allow-lists, and tiered pricing.",
              category: "NFT", website: "https://developers.metaplex.com/candy-machine"),

        .init(address: "p1exdMJcjVao65QdewkaZRUnU6VPSXhus9n2GzWfh98",
              name: "Metaplex Auction House",
              description: "On-chain NFT marketplace protocol. Powers decentralised NFT listings, bids, and sales with customisable fees.",
              category: "NFT", website: "https://metaplex.com"),

        // ── DEX / DeFi ────────────────────────────────────────────────────────

        .init(address: "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4",
              name: "Jupiter Aggregator v6",
              description: "Jupiter DEX aggregator v6. Routes swaps across Raydium, Orca, and 20+ pools to find the best price with minimal slippage.",
              category: "DeFi", website: "https://jup.ag"),

        .init(address: "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8",
              name: "Raydium AMM v4",
              description: "Raydium's Automated Market Maker. One of the largest DEX liquidity sources on Solana with pools for hundreds of token pairs.",
              category: "DeFi", website: "https://raydium.io"),

        .init(address: "CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK",
              name: "Raydium CLMM",
              description: "Raydium Concentrated Liquidity Market Maker. Provides capital-efficient liquidity positions within price ranges.",
              category: "DeFi", website: "https://raydium.io"),

        .init(address: "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc",
              name: "Orca Whirlpools",
              description: "Orca's concentrated liquidity DEX. Top-tier DeFi protocol for efficient trading and liquidity provision on Solana.",
              category: "DeFi", website: "https://orca.so"),

        .init(address: "9W959DqEETiGZocYWCQPaJ6sBmUzgfxXfqGeTEdp3aQP",
              name: "Orca AMM (Legacy)",
              description: "Orca's original constant-product AMM pools (legacy). Superseded by Whirlpools (CLMM) for most pairs.",
              category: "DeFi", website: "https://orca.so"),

        .init(address: "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX",
              name: "Serum DEX v3",
              description: "Serum's central limit order book program. Foundation for early Solana DeFi; largely succeeded by OpenBook.",
              category: "DeFi", website: nil),

        // ── Liquid Staking ────────────────────────────────────────────────────

        .init(address: "MarBmsSgKXdrN1egZf5sqe1TMai9K1rChYNDJgjq7aD",
              name: "Marinade Finance",
              description: "Liquid staking protocol. Stake SOL → receive mSOL. Earn ~7% APY while keeping tokens usable in DeFi.",
              category: "Staking", website: "https://marinade.finance"),

        .init(address: "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn",
              name: "Jito Stake Pool",
              description: "Jito liquid staking pool. Stake SOL → receive JitoSOL. Earns MEV rewards on top of ~7% staking APY.",
              category: "Staking", website: "https://jito.network"),

        // ── Governance / Multisig ─────────────────────────────────────────────

        .init(address: "SQDS4ep65T869zMMBKyuUq6aD6EgTu8psMjkvj52pCf",
              name: "Squads Multisig v4",
              description: "Squads Protocol for on-chain multisig wallets and program upgrade governance. Popular for DAO treasuries and team wallets.",
              category: "Governance", website: "https://squads.so"),

        .init(address: "GovER5Lthms3bLBqWub97yVrMmEogzX7xNjdXpPPCVZw",
              name: "SPL Governance",
              description: "Official Solana governance program. Used by DAOs for on-chain proposal creation, voting, and treasury execution.",
              category: "Governance", website: "https://realms.today"),

        // ── Bridges ───────────────────────────────────────────────────────────

        .init(address: "worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth",
              name: "Wormhole Bridge",
              description: "Wormhole cross-chain messaging protocol. Bridges tokens and messages between Solana, Ethereum, BNB Chain, and 20+ blockchains.",
              category: "Bridge", website: "https://wormhole.com"),

        // ── Lending / Borrowing ───────────────────────────────────────────────

        .init(address: "So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo",
              name: "Solend Protocol",
              description: "Algorithmic money market on Solana. Lend assets to earn yield or use them as collateral to borrow.",
              category: "DeFi", website: "https://solend.fi"),

        .init(address: "MFv2hWf31Z9kbCa1snEPdcgp168vLLAHkuiCK4z3Z8m",
              name: "marginfi v2",
              description: "Risk-isolated lending and borrowing protocol. Supports isolated risk tiers and liquidation via flash loans.",
              category: "DeFi", website: "https://marginfi.com"),
    ]
}
