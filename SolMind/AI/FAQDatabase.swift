import Foundation

// MARK: - FAQ Direct-Answer Database
// Pattern-matched static answers for the most common Solana/DeFi questions.
// Checked BEFORE any Foundation Models inference — zero latency, zero battery drain.
// Covers ~30 questions that account for the majority of knowledge-type queries.

struct FAQEntry {
    let patterns: [String]   // substring patterns (lowercased match against lowercased query)
    let answer: String
    let suggestions: [String]
}

enum FAQDatabase {

    // MARK: - Static Entries

    static let entries: [FAQEntry] = [

        // ── Devnet ──────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is devnet", "what's devnet", "explain devnet", "tell me about devnet", "what devnet"],
            answer: """
            ⚠️ DEVNET: **What is Devnet?**

            Devnet is Solana's public test network. All SOL and tokens here have **zero real-world value** — it's a safe sandbox for testing transactions without any risk.

            • Get free devnet SOL instantly by saying **"Get devnet SOL"**
            • Your wallet address is the same format as mainnet
            • You can test every feature: send, swap, mint NFTs, create tokens
            • Devnet is always available at `api.devnet.solana.com`
            """,
            suggestions: ["Get devnet SOL", "What is mainnet?", "What's my balance?"]
        ),

        // ── Transaction fees ────────────────────────────────────────────────────
        .init(
            patterns: ["transaction fee", "tx fee", "how much does a transaction cost",
                       "what are fees", "fee on solana", "how much is the fee", "solana fee"],
            answer: """
            ✅ DEVNET: **Solana Transaction Fees**

            Solana transactions cost approximately **$0.000025 USD** (~5,000 lamports) — ~1,000× cheaper than Ethereum.

            • **Base fee:** 5,000 lamports per signature
            • **Priority fees:** optional, speeds up processing during congestion
            • **Token account:** ~0.002 SOL one-time rent (recoverable on close)
            • **NFT mint:** ~0.000005 USD for compressed NFTs
            """,
            suggestions: ["What are lamports?", "What is rent?", "Send SOL to someone"]
        ),

        // ── Lamports ────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is a lamport", "what are lamports", "lamport to sol", "how many lamports", "what is lamport"],
            answer: """
            ✅ DEVNET: **Lamports**

            A lamport is the smallest unit of SOL, named after computing pioneer Leslie Lamport.

            • **1 SOL = 1,000,000,000 lamports** (1 billion)
            • Transaction fee ≈ 5,000 lamports (~$0.000025)
            • Rent-exempt deposit ≈ 890,880 lamports per kilobyte of data
            • Lamports are the unit RPC nodes use internally
            """,
            suggestions: ["What are Solana fees?", "What is rent?", "What's my balance?"]
        ),

        // ── Proof of History ────────────────────────────────────────────────────
        .init(
            patterns: ["proof of history", "what is poh", "how does poh", "explain poh", "poh consensus"],
            answer: """
            ✅ DEVNET: **Proof of History (PoH)**

            PoH is Solana's cryptographic clock — a Verifiable Delay Function (VDF) that creates a tamper-proof timestamp for every event, without waiting for network-wide agreement.

            • Enables **~400ms block times** (vs Ethereum's 12s)
            • Validators verify ordering without polling other nodes
            • Combined with **Tower BFT** (Proof of Stake) for finality
            • All validators run the same VDF sequence independently, then confirm
            """,
            suggestions: ["What is Sealevel?", "What is Tower BFT?", "How fast is Solana?"]
        ),

        // ── Sealevel ────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is sealevel", "sealevel", "parallel execution", "parallel transactions"],
            answer: """
            ✅ DEVNET: **Sealevel — Parallel Execution**

            Sealevel is Solana's runtime for executing thousands of smart contracts in parallel.

            • Transactions that touch different accounts run simultaneously
            • Transactions that share accounts are serialized (safety)
            • Enabled by Solana's account model: programs declare data dependencies upfront
            • Key reason Solana achieves 50,000+ theoretical TPS
            """,
            suggestions: ["What is Proof of History?", "How fast is Solana?", "What is Gulf Stream?"]
        ),

        // ── What is Solana ──────────────────────────────────────────────────────
        .init(
            patterns: ["what is solana", "explain solana", "tell me about solana",
                       "how does solana work", "why solana", "what can solana do"],
            answer: """
            ✅ DEVNET: **Solana**

            Solana is a high-performance Layer 1 blockchain built for speed and low cost.

            **Key stats:**
            • ~400ms block times · 3–5k TPS sustained · 50k+ theoretical
            • Transaction fees ~$0.000025 USD · ~2,000+ active validators

            **Core innovations:**
            • **Proof of History** — cryptographic clock for ordering
            • **Sealevel** — parallel transaction execution
            • **Gulf Stream** — mempool-less forwarding
            • **Turbine** — erasure-coded block propagation
            • **Firedancer** — Jump Trading's independent validator client
            """,
            suggestions: ["What is Proof of History?", "What is Sealevel?", "What can I do with SOL?"]
        ),

        // ── Staking ─────────────────────────────────────────────────────────────
        .init(
            patterns: ["how do i stake", "how to stake", "what is staking",
                       "staking sol", "native staking", "stake my sol", "what is native staking"],
            answer: """
            ✅ DEVNET: **Staking SOL**

            Native staking lets you delegate SOL to validators and earn ~7–8% APY.

            **Steps:**
            1. Choose a validator (commission <10%, high uptime, no freeze history)
            2. Delegate SOL → 1–2 epoch warm-up (~2 days)
            3. Earn rewards automatically each epoch (~2 days)
            4. Undelegate → 1–2 epoch cooldown before SOL is liquid again

            **Liquid Staking (no cooldown):**
            • **mSOL** (Marinade) ~7% APY
            • **jitoSOL** (Jito) ~8% APY + MEV tips
            • **bSOL** (BlazeStake) ~7% APY — all usable as DeFi collateral
            """,
            suggestions: ["What is liquid staking?", "What is mSOL?", "What is Marinade?"]
        ),

        // ── LSTs / Liquid staking ───────────────────────────────────────────────
        .init(
            patterns: ["liquid staking", "what is lst", "what are lsts", "liquid staking token",
                       "what is msol", "what is jitosol", "what is bsol"],
            answer: """
            ✅ DEVNET: **Liquid Staking Tokens (LSTs)**

            LSTs represent staked SOL that remains liquid — you earn staking rewards while keeping the token usable in DeFi.

            | Token | Protocol | APY | Bonus |
            |---|---|---|---|
            | **mSOL** | Marinade | ~7% | Governance |
            | **jitoSOL** | Jito | ~8% | MEV tips |
            | **bSOL** | BlazeStake | ~7% | — |

            LSTs are accepted as collateral on Kamino, MarginFi, and other money markets, letting you earn yield while also borrowing against your position.
            """,
            suggestions: ["How do I stake SOL?", "What is Kamino?", "What is MarginFi?"]
        ),

        // ── Rent ────────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is rent", "account rent", "rent-exempt", "rent exemption",
                       "storage rent", "solana rent"],
            answer: """
            ✅ DEVNET: **Account Rent**

            Solana charges a deposit to store data on-chain. To avoid recurring fees, accounts must hold a **rent-exempt** minimum balance.

            • ~0.00089 SOL per kilobyte of stored data
            • SPL token account rent-exempt: ~0.002 SOL (one-time)
            • Rent is **recoverable** — close the account and the SOL returns
            • SolMind creates token accounts automatically and handles rent for you
            """,
            suggestions: ["What are Solana fees?", "What is a token account?", "Create a token"]
        ),

        // ── Jupiter ─────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is jupiter", "explain jupiter", "tell me about jupiter",
                       "what is jup", "jupiter dex", "how does jupiter work", "how jupiter works"],
            answer: """
            ✅ DEVNET: **Jupiter**

            Jupiter is Solana's best DEX aggregator — routes swaps across 20+ liquidity pools (Raydium, Orca, Meteora…) for optimal pricing.

            **Features:**
            • ♻️ Smart order routing across all major DEXes
            • 📊 DCA — automated recurring buys
            • 📈 Limit Orders — set custom price targets
            • ⚡ Perps — on-chain perpetual futures
            • **JUP** — governance token

            ⚠️ **Note:** Jupiter operates on mainnet only. Devnet has no liquidity pools, so swaps here always fail — this is expected.
            """,
            suggestions: ["How do I swap tokens?", "What is Raydium?", "What is Orca?"]
        ),

        // ── Compressed NFTs ─────────────────────────────────────────────────────
        .init(
            patterns: ["what is compressed nft", "compressed nft", "cnft",
                       "what is bubblegum", "explain compressed nft", "how do compressed nfts work"],
            answer: """
            ✅ DEVNET: **Compressed NFTs (cNFTs)**

            Compressed NFTs use Merkle tree compression to store NFT data on-chain at a fraction of regular cost.

            • **Cost to mint:** ~$0.000005 per NFT (vs ~$0.01–0.10 for regular NFTs)
            • **Programs:** Metaplex Bubblegum + SPL Account Compression
            • **Verification:** Helius DAS API (`getAsset` / `getAssetsByOwner`)
            • SolMind mints cNFTs for free on devnet via Helius API

            Say **"mint me an NFT"** to try it — I'll collect image URL and traits first.
            """,
            suggestions: ["Mint me an NFT", "What is Metaplex?", "View my NFTs"]
        ),

        // ── Wallets ─────────────────────────────────────────────────────────────
        .init(
            patterns: ["best solana wallet", "what wallet", "phantom wallet",
                       "solflare", "backpack wallet", "which wallet should i use", "best wallet for solana"],
            answer: """
            ✅ DEVNET: **Solana Wallets**

            **Top wallets:**
            • **Phantom** — most popular, browser + mobile, excellent UX
            • **Solflare** — feature-rich, best staking integration
            • **Backpack** — supports xNFTs, built by Coral
            • **Ledger** — hardware wallet, highest security, use with any of the above

            You're already using **SolMind** — keys are stored in Apple Keychain (encrypted, Touch/Face ID protected). All AI inference is on-device via Apple Foundation Models.
            """,
            suggestions: ["How do I keep my wallet safe?", "What is a seed phrase?", "Is SolMind secure?"]
        ),

        // ── Seed phrase ─────────────────────────────────────────────────────────
        .init(
            patterns: ["what is a seed phrase", "what is mnemonic", "seed phrase",
                       "recovery phrase", "12 words", "24 words", "bip-39"],
            answer: """
            ✅ DEVNET: **Seed Phrases**

            A seed phrase (mnemonic) is a human-readable backup of your wallet's master key — 12 or 24 words from the BIP-39 word list.

            **Critical rules:**
            • ⛔ NEVER share it with anyone — ever
            • ⛔ No legitimate app ever asks for your seed phrase (it's always a scam)
            • ✅ Store offline in multiple physical locations
            • ✅ Anyone with your seed phrase controls ALL your funds

            SolMind stores keys in **Apple Keychain** (encrypted, sandboxed). Your seed phrase never leaves your device and is never used in AI prompts.
            """,
            suggestions: ["How do I keep my wallet safe?", "Is SolMind secure?", "What is a private key?"]
        ),

        // ── NFT marketplaces ─────────────────────────────────────────────────────
        .init(
            patterns: ["what is magic eden", "magic eden", "nft marketplace",
                       "where to sell nft", "where to buy nft", "tensor marketplace"],
            answer: """
            ✅ DEVNET: **NFT Marketplaces on Solana**

            • **Magic Eden** — largest Solana marketplace, cross-chain (ETH, BTC)
            • **Tensor** — professional orderbook for active traders
            • **Exchange.art** — curated 1:1 fine art NFTs
            • **Solanart** — one of the original Solana NFT marketplaces

            To view your NFTs in SolMind, tap the **Gallery** tab. SolMind uses the Helius DAS API to fetch compressed and standard NFTs.
            """,
            suggestions: ["View my NFT gallery", "Mint me an NFT", "What are compressed NFTs?"]
        ),

        // ── TPS / Speed ──────────────────────────────────────────────────────────
        .init(
            patterns: ["how fast is solana", "solana speed", "tps", "transactions per second",
                       "solana tps", "how many tps", "block time"],
            answer: """
            ✅ DEVNET: **Solana Speed**

            • **Block time:** ~400ms (Ethereum: 12s, Bitcoin: 10min)
            • **Sustained TPS:** 3,000–5,000
            • **Theoretical TPS:** 50,000+
            • **Finality:** ~12.8 seconds

            Achieved via **Sealevel** (parallel execution) + **Proof of History** (pre-established ordering). Firedancer (Jump Trading's client) targets 1,000,000 TPS as a future milestone.
            """,
            suggestions: ["What is Proof of History?", "What is Sealevel?", "What is Firedancer?"]
        ),

        // ── Helius ──────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is helius", "helius api", "helius rpc", "explain helius", "helius das"],
            answer: """
            ✅ DEVNET: **Helius**

            Helius is a Solana infrastructure provider powering SolMind's NFT features.

            • **Enhanced RPC nodes** — fast, reliable Solana access
            • **DAS API** — Digital Asset Standard: query any NFT or cNFT by owner
            • **Webhooks** — real-time on-chain event notifications
            • **Devnet minting API** — free compressed NFT minting (used by SolMind)

            SolMind uses Helius for the NFT gallery and cNFT minting.
            """,
            suggestions: ["Mint me an NFT", "View my NFT gallery", "What are compressed NFTs?"]
        ),

        // ── SPL / Token-2022 ─────────────────────────────────────────────────────
        .init(
            patterns: ["what is spl", "spl token", "what is token-2022", "token extensions",
                       "what are spl tokens", "how do spl tokens work"],
            answer: """
            ✅ DEVNET: **SPL Token Program & Token-2022**

            **SPL Token Program** — the standard for Solana fungible tokens (USDC, USDT, JUP…):
            • One mint address per token type
            • One Associated Token Account (ATA) per wallet per token
            • ~0.002 SOL rent per ATA (recoverable)

            **Token-2022 (Token Extensions)** — next-gen program with:
            • Transfer fees, interest-bearing accounts
            • Confidential transfers (privacy), non-transferable tokens
            • Metadata pointer, transfer hooks
            • EURC uses Token-2022 on Solana

            Say **"create a token"** to deploy your own SPL token on devnet.
            """,
            suggestions: ["Create a token", "What is an ATA?", "What is Token-2022?"]
        ),

        // ── Wormhole / bridging ──────────────────────────────────────────────────
        .init(
            patterns: ["what is wormhole", "how bridge", "how do i bridge", "cross-chain",
                       "bridge sol", "bridge to solana", "wormhole bridge"],
            answer: """
            ✅ DEVNET: **Cross-Chain Bridging on Solana**

            • **Wormhole** — largest Solana bridge, 30+ chains, **W** governance token
            • **deBridge** — fast cross-chain swaps, **DBR** token
            • **Mayan** — cross-chain swaps via Wormhole + Uniswap liquidity
            • **Allbridge Core** — stablecoin bridging (USDC/USDT)

            Bridged assets are tagged with their source (e.g., "Wormhole-wrapped ETH"). To bridge SOL to Ethereum, unwrap to native ETH and bridge back.

            ⚠️ DEVNET: cross-chain bridges are mainnet-only — no devnet liquidity.
            """,
            suggestions: ["What is DeFi on Solana?", "What is Jupiter?", "What's my balance?"]
        ),

        // ── DeFi on Solana ───────────────────────────────────────────────────────
        .init(
            patterns: ["what is defi", "defi on solana", "tell me about defi",
                       "solana defi", "how does defi work", "what can i do with defi"],
            answer: """
            ✅ DEVNET: **DeFi on Solana**

            Solana hosts one of the richest DeFi ecosystems:

            | Category | Protocols |
            |---|---|
            | DEX Aggregator | Jupiter (best entry), Orca, Raydium |
            | Lending | Kamino, MarginFi v2, Solend |
            | Liquid Staking | Marinade (mSOL), Jito (jitoSOL), BlazeStake (bSOL) |
            | Perps | Drift, Phoenix, Jupiter Perps |
            | Governance | Squads Multisig, SPL Governance (realms.today) |

            ⚠️ DEVNET: most DeFi protocols run on mainnet only. You can explore programs via `analyzeProgram` in chat.
            """,
            suggestions: ["What is Jupiter?", "What is Kamino?", "How do I stake SOL?"]
        ),

        // ── Firedancer ───────────────────────────────────────────────────────────
        .init(
            patterns: ["what is firedancer", "firedancer client", "jump trading validator"],
            answer: """
            ✅ DEVNET: **Firedancer**

            Firedancer is an independent Solana validator client built by **Jump Trading**, written in C for maximum performance.

            • Targets **1,000,000 TPS** theoretical throughput
            • Increases network resilience (second independent client = no single codebase failure)
            • Outperforms the original Rust-based Agave client in benchmarks
            • Franken-dancer (hybrid) deployed on mainnet; full Firedancer in testing

            Multiple validator clients = more decentralized, more resilient Solana.
            """,
            suggestions: ["What is Proof of History?", "How fast is Solana?", "What is a validator?"]
        ),

        // ── PDA ──────────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is a pda", "program derived address", "pda solana", "what is pda"],
            answer: """
            ✅ DEVNET: **Program Derived Addresses (PDAs)**

            PDAs are deterministic off-curve addresses controlled by programs, not private keys.

            • Derived from: `[seeds] + programId → PDA` via `findProgramAddress`
            • No private key exists — only the owning program can sign for them
            • Used for: program-owned escrows, game state, vaults, AMM pools
            • Always reproducible: same seeds + program = same address
            • Enables trustless composability between programs (CPIs)
            """,
            suggestions: ["What is a CPI?", "Tell me about Solana architecture", "What are programs?"]
        ),

        // ── Raydium ──────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is raydium", "raydium dex", "tell me about raydium", "how raydium works"],
            answer: """
            ✅ DEVNET: **Raydium**

            Raydium is one of Solana's largest DEXes — both an AMM and CLMM.

            • **AMM v4** — classic constant-product pools
            • **CLMM** — concentrated liquidity market maker (capital-efficient)
            • **LaunchLab** — token launch platform for new projects
            • **RAY** — governance and staking token
            • Integrated with Jupiter for best-route aggregation

            ⚠️ DEVNET: Raydium pools are mainnet-only. Use Jupiter (also mainnet only) for swaps in production.
            """,
            suggestions: ["What is Jupiter?", "What is Orca?", "How do I swap tokens?"]
        ),

        // ── Gulf Stream ──────────────────────────────────────────────────────────
        .init(
            patterns: ["what is gulf stream", "gulf stream solana", "mempool solana",
                       "solana mempool", "have a mempool", "does solana have",
                       "how does forwarding work", "no mempool"],
            answer: """
            ✅ DEVNET: **Gulf Stream — Mempool-less Transaction Forwarding**

            Gulf Stream replaces the traditional mempool with forward-looking transaction caching.

            • Transactions are forwarded directly to **upcoming validator leaders** before their slot
            • Validators can pre-load transactions into memory, reducing confirmation latency
            • Result: sub-second transaction processing with **zero mempool congestion**
            • Contrast with Ethereum: transactions wait in a shared mempool (gas wars, MEV bots)

            Solana has **no gas wars** — fees are fixed and tiny (~$0.000025 per tx).
            """,
            suggestions: ["What is Proof of History?", "What is Turbine?", "How fast is Solana?"]
        ),

        // ── Turbine ──────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is turbine", "turbine block propagation", "erasure coding solana",
                       "how blocks propagate", "block propagation"],
            answer: """
            ✅ DEVNET: **Turbine — Block Propagation**

            Turbine is Solana's block propagation protocol, inspired by BitTorrent.

            • Breaks blocks into small **shreds** (erasure-coded packets)
            • Shreds cascade through a tree of validators — no single point of failure
            • **Erasure coding** means up to 1/3 of shreds can be lost and the block still reconstructs
            • Enables fast propagation to 2,000+ validators with minimal bandwidth per node

            This is how Solana achieves high throughput without requiring every node to download the full block from the leader.
            """,
            suggestions: ["What is Gulf Stream?", "What is Proof of History?", "What is Firedancer?"]
        ),

        // ── Tower BFT ────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is tower bft", "tower bft", "solana consensus", "how consensus works",
                       "what is bft", "byzantine fault"],
            answer: """
            ✅ DEVNET: **Tower BFT — Solana's Consensus**

            Tower BFT is Solana's Proof of Stake consensus mechanism, optimized using Proof of History.

            • Based on **PBFT** (Practical Byzantine Fault Tolerance)
            • Validators vote on the state of the blockchain using **PoH-timestamped votes**
            • Votes have an **exponentially increasing lockout** — the longer you commit, the longer you're locked to that fork
            • Achieves finality in ~12.8 seconds on average
            • Tolerates up to 1/3 of validators being faulty or malicious

            Combined with PoH, Tower BFT lets validators agree on order without round-trip coordination.
            """,
            suggestions: ["What is Proof of History?", "What is Sealevel?", "What is a validator?"]
        ),

        // ── Validators ───────────────────────────────────────────────────────────
        .init(
            patterns: ["what is a validator", "what are validators", "how validators work",
                       "validators work", "how to become a validator", "solana validators", "validator node"],
            answer: """
            ✅ DEVNET: **Solana Validators**

            Validators are nodes that process transactions and vote on the blockchain state.

            • **2,000+ active validators** on mainnet
            • **Leader rotation**: each validator takes turns producing blocks (one slot = ~400ms)
            • **Staking**: SOL holders delegate to validators and earn ~7–8% APY
            • **Commission**: validators keep 0–10% of rewards (choose validators with <10%)
            • **Hardware**: requires high-performance server (1TB+ NVMe SSD, 256GB RAM, fast CPU)

            To choose a validator for staking: prefer low commission, high uptime, no freeze history. Tools: **validators.app**, **solanabeach.io**.
            """,
            suggestions: ["How do I stake SOL?", "What is liquid staking?", "What is Tower BFT?"]
        ),

        // ── Orca ─────────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is orca", "orca dex", "orca whirlpool", "tell me about orca",
                       "how does orca work"],
            answer: """
            ✅ DEVNET: **Orca**

            Orca is a developer-friendly Solana DEX known for its concentrated liquidity pools.

            • **Whirlpools** — CLMM (Concentrated Liquidity Market Maker), capital-efficient
            • **ORCA** — governance and fee-sharing token
            • Clean SDK and documentation — popular with builders
            • Integrated with Jupiter for best-route aggregation

            ⚠️ DEVNET: Orca pools run on mainnet only. Devnet swaps via Jupiter/Orca will fail.
            """,
            suggestions: ["What is Jupiter?", "What is Raydium?", "Swap SOL for USDC"]
        ),

        // ── Kamino ───────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is kamino", "kamino finance", "automated liquidity",
                       "kamino lending", "tell me about kamino"],
            answer: """
            ✅ DEVNET: **Kamino Finance**

            Kamino is Solana's leading automated liquidity and lending protocol.

            • **Automated LP vaults** — auto-rebalances positions in Orca/Raydium CLMMs
            • **Lending market** — supply/borrow USDC, SOL, LSTs with competitive rates
            • **Leveraged yield** — borrow against LSTs to amplify staking yields
            • **KMNO** — governance token, distributes protocol fees to stakers
            • LSTs (mSOL, jitoSOL, bSOL) accepted as collateral

            ⚠️ DEVNET: Kamino is mainnet-only.
            """,
            suggestions: ["What is MarginFi?", "What is liquid staking?", "What is DeFi on Solana?"]
        ),

        // ── MarginFi ─────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is marginfi", "margin fi", "marginfi lending", "tell me about marginfi",
                       "flash loans"],
            answer: """
            ✅ DEVNET: **MarginFi v2**

            MarginFi is an isolated-risk lending protocol on Solana.

            • **Isolated pools** — each asset pair is risk-isolated (failure doesn't cascade)
            • **Flash loans** — borrow and repay in a single transaction (no collateral needed)
            • **MRGN** — governance token
            • Accepts SOL, USDC, LSTs as collateral
            • Competitive supply/borrow rates; lower liquidation risk than cross-margin protocols

            ⚠️ DEVNET: MarginFi is mainnet-only.
            """,
            suggestions: ["What is Kamino?", "What is liquid staking?", "What is DeFi on Solana?"]
        ),

        // ── Marinade ─────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is marinade", "marinade staking", "what is mnde",
                       "tell me about marinade", "marinade native", "marinade liquid"],
            answer: """
            ✅ DEVNET: **Marinade Finance**

            Marinade is Solana's largest liquid staking protocol.

            • **mSOL** — liquid staking token, ~7% APY, no lockup
            • Distributes stake across 100+ validators (decentralization)
            • **Marinade Native** — native stake with same APY, no smart contract risk
            • **MNDE** — governance token, earns from protocol fees
            • mSOL usable as collateral on Kamino, MarginFi, and other protocols

            Marinade pioneered liquid staking on Solana and remains the #1 protocol by TVL.
            """,
            suggestions: ["What is jitoSOL?", "How do I stake SOL?", "What is liquid staking?"]
        ),

        // ── Compressed NFTs ──────────────────────────────────────────────────────
        .init(
            patterns: ["what are compressed nfts", "what is a compressed nft", "cnft",
                       "compressed nft vs regular", "bubblegum nft", "how to mint compressed",
                       "compressed nft cost", "how cheap are compressed nfts"],
            answer: """
            ✅ DEVNET: **Compressed NFTs (cNFTs)**

            Compressed NFTs store metadata in a Merkle tree on-chain instead of individual accounts — dramatically reducing cost.

            | | Regular NFT | Compressed NFT |
            |---|---|---|
            | **Cost to mint** | ~0.01 SOL | ~0.000005 SOL |
            | **Storage** | Separate account per NFT | Merkle tree |
            | **Program** | Metaplex Token Metadata | Bubblegum + Account Compression |
            | **API** | Standard RPC | Helius DAS API |

            SolMind uses **Helius minting API** for cNFTs — say "Mint me an NFT" to try it. Helius minting is free on devnet.
            """,
            suggestions: ["Mint me an NFT", "View my NFT gallery", "What is Metaplex?"]
        ),

        // ── Wallets ──────────────────────────────────────────────────────────────
        .init(
            patterns: ["what is phantom", "phantom wallet", "what is solflare", "solana wallet",
                       "best wallet", "what wallet should i use", "backpack wallet",
                       "what wallets work with solana"],
            answer: """
            ✅ DEVNET: **Solana Wallets**

            Popular Solana wallets:

            | Wallet | Platform | Key Feature |
            |---|---|---|
            | **Phantom** | Browser + mobile | Most popular, built-in swap |
            | **Solflare** | Browser + mobile | Advanced staking UI |
            | **Backpack** | Browser + mobile | xNFT apps, bespoke UX |
            | **OKX Wallet** | Browser + mobile | Cross-chain support |
            | **SolMind** | macOS | AI-powered, on-device AI inference |

            **SolMind** stores keys in Apple Keychain — encrypted, sandboxed, protected by Touch/Face ID. No keys ever leave your device.
            """,
            suggestions: ["What's my balance?", "How is my wallet secured?", "What is devnet?"]
        ),

        // ── What can I do with SOL ────────────────────────────────────────────────
        .init(
            patterns: ["what can i do with sol", "what can i do with solana", "how to use sol",
                       "use cases for sol", "sol use case", "what do people use sol for"],
            answer: """
            ✅ DEVNET: **What can you do with SOL?**

            SOL is the native currency of Solana. With SolMind on devnet you can:

            • **Get free SOL** — say "Get devnet SOL" for an instant airdrop
            • **Send SOL** — send to any Solana address in seconds
            • **Swap tokens** — convert SOL ↔ USDC, USDT, BONK, JUP and more (via Jupiter on mainnet)
            • **Mint NFTs** — create compressed NFTs via Helius for almost nothing
            • **Create tokens** — deploy your own SPL fungible token (~0.005 SOL)
            • **Stake** — delegate to validators and earn ~7–8% APY (mainnet)
            • **DeFi** — lend, borrow, provide liquidity, earn yield (mainnet, Kamino/MarginFi/Marinade)

            Everything works on devnet — zero real money required for testing!
            """,
            suggestions: ["Get devnet SOL", "Mint me an NFT", "What's my balance?", "Swap SOL for USDC"]
        ),

        // ── OpenBook / order books ───────────────────────────────────────────────
        .init(
            patterns: ["what is openbook", "openbook dex", "order book solana",
                       "clob solana", "serum successor", "what happened to serum"],
            answer: """
            ✅ DEVNET: **OpenBook v2**

            OpenBook v2 is Solana's primary on-chain Central Limit Order Book (CLOB) DEX, the successor to the defunct Serum.

            • **CLOB** — maker/taker model with real bids and asks (vs AMMs)
            • Permissionless market creation — anyone can list any token pair
            • Built after FTX/Serum collapse — community-governed, no central key holders
            • Used by Jupiter as one of its liquidity sources for optimal routing
            • **Phoenix** is an alternative permissionless CLOB on Solana

            ⚠️ DEVNET: OpenBook markets are mainnet-only.
            """,
            suggestions: ["What is Jupiter?", "What is Raydium?", "What is DeFi on Solana?"]
        ),
    ]

    // MARK: - Lookup

    static func directAnswer(for query: String) -> FAQEntry? {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return entries.first { entry in
            entry.patterns.contains { q.contains($0) }
        }
    }
}
