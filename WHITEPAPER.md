# SolMind: On-Device AI Meets Self-Custodial Finance

**A Whitepaper for the Colosseum Frontier Hackathon 2026**

---

## Abstract

SolMind is a native multiplatform wallet application (macOS, iOS, iPadOS, visionOS) that combines Apple's Foundation Models framework with the Solana blockchain to deliver a natural-language interface for decentralized finance. By leveraging an on-device large language model with tool calling capabilities, SolMind enables users to execute blockchain operations — checking balances, sending tokens, swapping assets, viewing NFTs, and requesting faucet airdrops — through conversational prompts, while ensuring that all AI inference happens locally. No financial intent data, no portfolio information, and no transaction details ever leave the user's device during AI processing. The AI is enriched with a compressed Solana ecosystem knowledge base (DeFi protocols, NFT standards, staking, wallet security), live network statistics (epoch, TPS), and contextual wallet state injected at session start — all processed on-device. SolMind runs natively on Mac, iPhone, iPad, and Apple Vision Pro from a single shared codebase. **This hackathon MVP operates exclusively on Solana Devnet with all sponsor APIs in sandbox/test mode.**

---

## 1. Problem Statement

### 1.1 Crypto UX Remains a Barrier

Despite years of iteration, interacting with blockchain wallets still demands specialized knowledge: navigating token lists, pasting addresses, understanding gas fees, approving transactions through multi-step flows, and decoding program instructions. This complexity is the single largest barrier to mainstream adoption.

### 1.2 AI Wallets Leak Financial Data

Recent attempts to solve this with AI assistants (ChatGPT plugins, cloud-based copilots) introduce a new problem: every query, every balance check, every transaction intent is sent to a remote server. Users must trust that third-party AI providers will not log, analyze, or expose their financial behavior. This is fundamentally at odds with the self-sovereignty ethos of crypto.

### 1.3 No Native Desktop or Spatial Wallet for Solana

The Solana ecosystem's wallet landscape is dominated by browser extensions (Phantom, Backpack) and mobile apps. Native desktop applications — with deeper OS integration, better performance, and richer UI capabilities — are virtually nonexistent. Power users who spend hours on their Mac have no first-class wallet experience. Meanwhile, Apple Vision Pro launched a new computing paradigm with spatial interfaces, yet no Solana wallet exists for visionOS. The entire spatial crypto experience is greenfield.

---

## 2. Solution: SolMind

SolMind addresses all three problems with a single design decision: **bring the AI to the device, not the data to the AI.**

### 2.1 Core Thesis

Apple's Foundation Models framework (introduced at WWDC 2025, shipping with macOS 26, iOS 26, iPadOS 26, and visionOS 26) provides a capable on-device LLM with structured output generation and tool calling. By implementing Solana blockchain operations as Foundation Models `Tool` protocol conformances, we create an AI agent that can understand natural-language financial intent and execute it on-chain — entirely locally, on every Apple platform.

### 2.2 Design Principles

1. **Privacy by architecture** — AI inference is on-device. No API keys for AI providers. No telemetry on financial intent.
2. **Conversational, not navigational** — Users describe what they want; the AI determines how to do it.
3. **Confirmation before execution** — Every state-changing operation produces a typed `TransactionPreview` via guided generation. Users must explicitly approve.
4. **macOS-first, truly multiplatform** — Shared Swift Packages ensure 95%+ code reuse across macOS, iOS, iPadOS, and visionOS. Spatial interfaces on Vision Pro are a progressive enhancement.

---

## 3. Technical Architecture

### 3.1 System Overview

```
┌─────────────────────────────────────────────────────┐
│               SolMind Application                   │
│   SwiftUI · macOS / iOS / iPadOS / visionOS         │
│                                                     │
│   SolanaStatsBar ── SolanaStatsViewModel            │
│   Suggestion chips ── SuggestionEngine              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │    Apple Foundation Models (On-Device)       │   │
│  │                                              │   │
│  │  SystemLanguageModel.default                 │   │
│  │  LanguageModelSession(instructions:)         │   │
│  │  System prompt: AIInstructions               │   │
│  │    + SolanaKnowledge (DeFi/NFTs/staking)     │   │
│  │  First-message context block:                │   │
│  │    wallet · balance · USD · stats hint       │   │
│  │                                              │   │
│  │  Tool Calling ──┬── BalanceTool              │   │
│  │                 ├── FaucetTool               │   │
│  │                 ├── SendTool                 │   │
│  │                 ├── SwapTool                 │   │
│  │                 ├── PriceTool                │   │
│  │                 ├── NFTTool                  │   │
│  │                 ├── MintNFTTool              │   │
│  │                 ├── CreateTokenTool          │   │
│  │                 ├── TransactionHistoryTool   │   │
│  │                 └── OnRampTool (sandbox)     │   │
│  └─────────────────┬────────────────────────────┘   │
│                    │                                │
│  ┌─────────────────┴────────────────────────────┐   │
│  │          Wallet Abstraction Layer            │   │
│  │                                              │   │
│  │  WalletManager + LocalWallet                 │   │
│  │  CryptoKit Curve25519 (Ed25519 keypair)      │   │
│  │  Apple Keychain (private key storage)        │   │
│  └─────────────────┬────────────────────────────┘   │
│                    │                                │
│  ┌─────────────────┴────────────────────────────┐   │
│  │         External Service Layer               │   │
│  │                                              │   │
│  │  Solana JSON-RPC — Devnet (public endpoint)  │   │
│  │    · getBalance · sendTransaction            │   │
│  │    · getEpochInfo · getRecentPerfSamples     │   │
│  │  Solana Faucet — Devnet airdrop              │   │
│  │  Jupiter V6 API — price oracle + swap        │   │
│  │  Helius DAS + cNFT API — Devnet              │   │
│  │  Circle USDC Faucet — Devnet test tokens     │   │
│  │  MoonPay — Sandbox (fiat on-ramp URL)        │   │
│  │  UserDefaults — stats + price persistence    │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### 3.2 Foundation Models Integration

The Foundation Models framework provides three capabilities that map directly to wallet operations:

#### 3.2.1 Text Generation & Understanding

The on-device LLM interprets user intent from natural language. A `LanguageModelSession` is initialized with system-level `Instructions` that define the assistant's role, constraints, and embedded Solana ecosystem knowledge:

```swift
let session = LanguageModelSession(instructions: Instructions(
    AIInstructions.system  // ~20 rules + SolanaKnowledge.core
))
```

The system prompt embeds `SolanaKnowledge.core` — a compressed reference covering Solana's consensus mechanism (PoH + Tower BFT), DeFi protocols (Jupiter, Raydium, Kamino, MarginFi, Drift, Meteora, Jito), NFT standards (cNFTs via Bubblegum, Metaplex Core), staking options (native vs liquid), and wallet security best practices. This allows the model to answer ecosystem questions accurately without any network round-trips, preserving the on-device privacy guarantee.

#### 3.2.2 Session Context Injection

At the start of every new conversation, `ChatViewModel` prepends a context block to the user's first message. This block is constructed by `AIInstructions.contextBlock(...)` and contains the wallet address, current SOL balance, USD equivalent, token count, live network stats summary, and an optional knowledge hint if the opening query matches a specific Solana topic:

```swift
// Example first-message prefix (prepended once per session, never repeated):
// [Context: Wallet: 7xKp...3rM | Balance: 5.20 SOL | $728.00 | 3 token(s)
//  | SOL: $140.00 | Epoch 750 (62%) | TPS: ~2800]
// [Knowledge hint: Solana staking: Native staking delegates to validators…]
```

This gives the model immediate awareness of the user's financial context without requiring a `getBalance` tool call on every session start — reducing latency and improving response coherence.

#### 3.2.3 Tool Calling

Each blockchain operation is encapsulated as a `Tool` conformance. When the user says "send 0.5 SOL to 7xKp...", the model identifies that the `sendTokens` tool should be invoked, extracts the parameters (recipient address, amount 0.5, tokenMint nil), and calls the tool. The tool's return value — a signed transaction signature or error — is fed back to the model for natural language response generation.

```swift
struct FaucetTool: Tool {
    let name = "getFromFaucet"
    let description = "Requests free devnet SOL from the Solana faucet to fund the wallet for testing"

    struct Input: Codable {
        let amount: Double?  // 1-2 SOL per request, defaults to 1
    }

    func call(input: Input) async throws -> String {
        let sol = min(input.amount ?? 1.0, 2.0)  // Cap at 2 SOL per airdrop
        let lamports = UInt64(sol * 1_000_000_000)
        let signature = try await solanaClient.requestAirdrop(
            to: walletManager.publicKey, lamports: lamports
        )
        return "Airdrop requested: \(sol) devnet SOL. TX: \(signature)"
    }
}
```

```swift
struct SendTool: Tool {
    let name = "sendTokens"
    let description = "Sends SOL or SPL tokens to a recipient address or .sol domain"

    struct Input: Codable {
        let recipient: String   // Address or .sol domain
        let amount: Double      // Amount in token units
        let tokenMint: String?  // nil for native SOL
    }

    func call(input: Input) async throws -> String {
        let resolved = try await resolveAddress(input.recipient)
        let tx = try await buildTransferTransaction(
            to: resolved, amount: input.amount, mint: input.tokenMint
        )
        // Present TransactionPreview for user confirmation
        let confirmed = try await presentPreview(tx)
        guard confirmed else { return "Transaction cancelled by user." }
        let signature = try await walletManager.signAndSend(tx)
        return "Transaction sent. Signature: \(signature)"
    }
}
```

#### 3.2.4 Guided Generation

For structured outputs, the `@Generable` macro ensures the model produces typed Swift values rather than freeform text. This is critical for transaction previews where accuracy matters:

```swift
@Generable
struct TransactionPreview {
    @Guide(description: "The action being performed: send, swap, etc.")
    var action: String

    @Guide(description: "Amount in token units")
    var amount: Double

    @Guide(description: "Recipient address or .sol domain")
    var recipient: String

    @Guide(description: "Estimated network fee in SOL")
    var estimatedFee: Double

    @Guide(description: "A one-sentence human-readable summary")
    var summary: String
}
```

### 3.3 Wallet Layer

SolMind uses self-custodial Ed25519 keypairs generated locally on the device using CryptoKit's `Curve25519.Signing` API — the same elliptic curve Solana uses. The app supports **multiple keypairs**: each private key is stored as an independent Keychain item keyed by its base58 public address. The user can generate new addresses, switch between them, and delete old ones entirely from the Wallets screen.

| Aspect | Implementation |
|---|---|
| Key generation | `Curve25519.Signing.PrivateKey()` (CryptoKit) |
| Public key encoding | Base58 (Bitcoin alphabet) → Solana address |
| Signing | `privateKey.signature(for: messageData)` |
| Storage | Keychain `kSecClassGenericPassword`, `kSecAttrAccount` = base58 public key |
| Access control | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Active wallet | Tracked via `UserDefaults` (`fr.cybou.SolMind.activeWallet`) |
| Multiple wallets | `LocalWallet.allAddresses()` enumerates all stored keypairs |
| Legacy migration | Old single-key items auto-migrated to per-address scheme on first launch |

This provides full self-custody with zero third-party SDK dependencies.

### 3.4 Live Network Intelligence

SolMind surfaces live Solana network data without requiring the user to ask for it.

#### 3.4.1 SolanaNetworkService

`SolanaNetworkService` is a Swift `actor` that fires two concurrent RPC calls every two minutes:

```swift
async let epochData  = postRPC("getEpochInfo",  params: [])
async let perfData   = postRPC("getRecentPerformanceSamples", params: [["limit": 1]])
```

The resulting `SolanaNetworkStats` struct (epoch number, slot index, slot progress, absolute slot, TPS) is:
- Persisted to `UserDefaults` as a `Codable` blob so the stats bar is never blank on cold launch
- Published through `SolanaStatsViewModel` (`@Observable @MainActor`) to all views via SwiftUI's environment

#### 3.4.2 SolanaStatsBar

A compact 28pt-height bar at the top of the chat view displays:
- **SOL price** — from `PriceService` (Jupiter Price API v2, 30s cache)
- **Epoch progress** — epoch number with an inline capsule progress bar (e.g., `Epoch 750 ▓▓▓▓▓▒▒▒ 62%`)
- **TPS** — current transactions per second (e.g., `~2,800 TPS`)

A refresh button triggers `SolanaStatsViewModel.refresh()` which re-fetches both price and network stats concurrently.

#### 3.4.3 SuggestionEngine

After every AI response, `SuggestionEngine.suggestions(for:userMessage:walletHasBalance:)` performs keyword matching on the AI response and user message to generate 3–4 relevant follow-up prompts. Examples:

| Context | Suggestions |
|---|---|
| Balance response | "Check token balances", "Send SOL", "What's the SOL price?", "Get more devnet SOL" |
| Swap response | "Check my balance", "Swap more tokens", "What's the SOL price?" |
| NFT response | "Mint another NFT", "View my NFTs", "Check my balance" |
| Error response | "Try again", "Check my balance", "Get help" |

Chips are displayed in a horizontal `ScrollView` above the chat input and are cleared the moment the user sends a new message.

### 3.5 External Services (Devnet / Sandbox)

All external services are configured for devnet or sandbox mode. No real funds or mainnet endpoints are used.

| Service | Purpose | Integration | Mode |
|---|---|---|---|
| Solana JSON-RPC (public devnet) | Balance, transactions, epoch info, TPS | URLSession + JSON-RPC 2.0 | **Devnet** |
| Solana Faucet | Free SOL for testing via `requestAirdrop` | Built-in RPC method | **Devnet** |
| Jupiter V6 API | DEX aggregation; price oracle (30s cache) | REST API (no auth) | **Devnet** |
| Helius DAS API | Token metadata, NFT data, cNFT minting | REST API (API key) | **Devnet** |
| MoonPay | Fiat on-ramp simulation | Sandbox URL opened in browser | **Sandbox** |

### 3.6 Multiplatform Code Sharing

All code lives in a single app target with `#if os(...)` branches for platform-specific behavior. No third-party Swift packages are used — the entire implementation depends only on Apple frameworks.

```
SolMind/ (single app target)
├── AI/              # AISession, AIInstructions, SolanaKnowledge, SuggestionEngine,
│                    # 10 Tool conformances
├── Solana/          # SolanaClient (actor), TransactionBuilder, Keypair, Base58
├── Wallet/          # WalletManager (multi-keypair), LocalWallet (Keychain)
├── Services/        # JupiterService, HeliusService, PriceService,
│                    # SolanaNetworkService (epoch/TPS), ConversationStore
├── Views/           # ChatView, MessageBubble, SolanaStatsBar, NFTGalleryView,
│                    # PortfolioView, ConversationSidebar, TransactionPreviewCard,
│                    # WalletSetupView, WalletPickerView, PortfolioOrnamentView
├── ViewModels/      # ChatViewModel (@MainActor), WalletViewModel (@MainActor),
│                    # SolanaStatsViewModel (@MainActor, @Observable)
├── Models/          # ChatMessage, Conversation (Codable), TransactionPreview (@Generable)
└── Config/          # SolanaConfig, Secrets
```

Platform navigation strategy:
- **macOS / visionOS**: `NavigationSplitView` with `ConversationSidebar` → `AppDestination` enum drives detail pane (`chat`, `portfolio`, `nftGallery`, `walletPicker`)
- **iOS / iPadOS**: `TabView` with Chat, Portfolio, NFTs, Wallets tabs
- **visionOS extra**: `.ornament(attachmentAnchor: .scene(.leading))` with `PortfolioOrnamentView` + `.glassBackgroundEffect()`

---

## 4. Privacy Model

SolMind's privacy guarantee rests on a simple architectural fact: **the AI model runs entirely on-device.**

| Data | Where it's processed | Leaves device? |
|---|---|---|
| User prompts ("send 0.5 SOL to 7xKp...") | On-device Foundation Models | No |
| AI inference & tool selection | On-device Foundation Models | No |
| Solana ecosystem knowledge (DeFi, NFTs…) | Embedded in system prompt — on-device | No |
| Context injection (wallet, balance, stats) | Built locally — on-device | No |
| Wallet private keys | CryptoKit Curve25519 + Apple Keychain | No |
| Network stats (epoch, TPS) | Fetched from public Solana RPC | Yes (public data) |
| Balance queries | Solana RPC (public data) | Yes (public blockchain data) |
| Transaction submission | Solana network | Yes (on-chain by nature) |
| Token prices, metadata | Jupiter / Helius APIs | Yes (public data) |

The critical distinction: **intent** and **portfolio context** never leave the device. Only the execution of on-chain actions — which is inherently public — touches external services. There is no AI API key, no cloud inference endpoint, and no telemetry on what users ask the AI to do.

This stands in stark contrast to cloud-based AI wallet assistants (e.g., those built on OpenAI or Anthropic APIs), where every prompt — including amounts, addresses, and portfolio details — is sent to a third party.

---

## 5. Safety & Security

### 5.1 Transaction Confirmation

Every state-changing operation requires explicit user confirmation. The AI generates a `TransactionPreview` via guided generation, which is rendered as a native SwiftUI card. The user must tap **Confirm** before any transaction is signed or broadcast.

### 5.2 Address Validation

All addresses extracted by the AI from natural language are validated against Solana's base58 format before use. `.sol` domain resolution goes through the SNS (Solana Name Service) registry on-chain. The system never trusts the AI's raw output for addresses.

### 5.3 Amount Limits

Configurable per-transaction and daily limits prevent accidental large transfers. The AI warns users when a requested amount exceeds their configured threshold.

### 5.4 Foundation Models Guardrails

Apple's built-in `Guardrails` flag sensitive content in model input and output. SolMind layers additional instructions that prevent the AI from:
- Providing financial advice or price predictions
- Recommending specific tokens to buy
- Executing transactions without showing a preview
- Operating on mainnet without explicit user configuration

### 5.5 No Seed Phrase Exposure

Private keys are generated locally using `CryptoKit.Curve25519.Signing.PrivateKey()`, stored in the Apple Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, and never exposed to the AI model or application-level code. The AI receives only the wallet's public address.

---

## 6. User Experience

### 6.1 Onboarding (30 seconds)

1. Open SolMind — **⚠️ DEVNET** badge visible in toolbar; live SOL price + epoch progress shown in stats bar
2. Tap **Create Wallet** — first Ed25519 keypair generated locally on device
3. Public address displayed; private key written to Apple Keychain
4. AI greets with your devnet address and suggests: "Want me to get you some free devnet SOL from the faucet?"
5. Generate additional wallets anytime via the **Wallets** tab / sidebar entry
6. Start testing: send, swap, check NFTs — all on devnet with test tokens
7. After each AI response, contextual suggestion chips appear — tap to continue the conversation naturally

### 6.2 Example Interactions

**Balance check (with context):**
> "How much SOL do I have?"
> → Session starts with context block injected (wallet + balance already known to AI)
> → AI may respond immediately without calling `getBalance`: "You have 5.20 SOL (~$728)"
> → Suggestion chips appear: ["Check token balances", "What's the SOL price?", "Send SOL", "Get more devnet SOL"]

**Faucet airdrop:**
> "I need some SOL to test with"
> → AI calls `getFromFaucet` → "Airdropped 1 SOL to your devnet wallet. Balance is now 6.20 SOL."
> → Suggestion chips appear: ["Check my balance", "Send SOL", "Swap tokens", "Mint an NFT"]

**Token transfer:**
> "Send 0.5 SOL to 3A5vT2..."
> → AI calls `sendTokens` → preview card: "⚠️ DEVNET — Send 0.5 SOL to 3A5vT2..." → user confirms → "Sent! TX: 5xA3..."
> → AI response rendered with **bold** and inline `code` via AttributedString markdown
> → Response time shown in toolbar: "0.8s"

**Swap:**
> "Swap 0.1 SOL for USDC"
> → AI calls `swapTokens` via Jupiter → preview → confirm → done
> (Note: Jupiter is mainnet-only; on devnet the quote will fail and AI explains the limitation)

**Ecosystem question (no tool needed):**
> "What is Jito and how does it work?"
> → AI answers from embedded `SolanaKnowledge` — no external call, fully on-device
> → Suggestion chips: ["How do I stake SOL?", "What's MEV?", "Get SOL price"]

**Mint an NFT:**
> "Mint me an NFT called SolMind Pioneer"
> → AI calls `mintNFT` → Helius creates compressed NFT on devnet for free → "Your NFT has been minted!"

**Create a token:**
> "Create a token called SolDEMO with 1 million supply"
> → AI calls `createToken` → two transactions sent (createMint + mintTokens) → mint address returned

**Network stats question:**
> "What epoch are we in?"
> → AI answers from injected context block: "We're in epoch 750, about 62% through"
> → Live stats also visible in the SolanaStatsBar at the top of chat

**Portfolio overview:**
> "Show me everything I have"
> → AI calls `getBalance` (all tokens) + `getNFTs` → Portfolio tab shows total USD value header + recent activity

**Fiat on-ramp:**
> "I want to buy $200 worth of SOL"
> → AI calls `buyWithFiat` → MoonPay sandbox flow opens → simulated purchase

### 6.3 macOS Desktop Experience

- Full window with resizable sidebar for conversation history
- Native macOS toolbar with quick actions
- Keyboard-first: type prompts, use `⌘Enter` to send
- Menu bar widget for quick balance check (stretch goal)

### 6.4 iPadOS Experience

- Multi-column `NavigationSplitView` with conversation list + chat + detail panels
- Full keyboard and trackpad support (Magic Keyboard)
- Stage Manager compatible — run SolMind alongside Safari or a DEX
- Apple Pencil handwriting input via Scribble for entering prompts
- Phantom deeplink integration for wallet connection

### 6.5 iOS Experience

- Compact single-column `NavigationStack` layout
- Swipe gestures for conversation management
- Phantom deeplink integration for wallet connection
- Apple Pay integration for MoonPay fiat on-ramp

### 6.6 visionOS Experience (Apple Vision Pro)

- Standard SwiftUI window for chat interface — works with zero platform-specific code
- **Ornaments** for quick-access portfolio summary and balance display alongside the main window
- **Volumetric transaction cards** — TransactionPreview rendered as 3D floating cards the user can inspect from any angle
- **Gaze + tap confirmation** — look at the Confirm button and tap to approve transactions
- **Multi-window** — open separate windows for portfolio, chat, and NFT gallery side by side in your space
- Self-custodial Keychain wallet is the primary wallet method — no browser extension required on visionOS
- Foundation Models runs natively on Vision Pro's M-series chip — same on-device privacy guarantee

---

## 7. Sponsor Integrations

SolMind integrates multiple Colosseum Frontier Hackathon sponsors:

| Sponsor | Integration | Depth |
|---|---|---|
| **Jupiter** | DEX aggregation — `swapTokens` tool calls Jupiter V6 `/quote` and `/swap` APIs; price oracle for `getPrice` | Core |
| **Helius** | DAS API — `getNFTs` via `getAssetsByOwner`; **compressed NFT minting** via `mintCompressedNft` RPC extension | Core |
| **MoonPay** | Fiat on-ramp — `buyWithFiat` tool opens MoonPay sandbox URL in browser | Core |

### Devnet Token Ecosystem

| Token | Mint Address | How to Acquire |
|---|---|---|
| SOL (native) | — | `getFromFaucet` AI tool, or [faucet.solana.com](https://faucet.solana.com) |
| USDC (devnet) | `4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU` | [faucet.circle.com](https://faucet.circle.com) — Circle's official devnet USDC faucet |
| Custom SPL tokens | User-defined at creation time | `createToken` AI tool — deploys a new token mint with custom symbol/supply |
| Compressed NFTs | Helius-generated asset ID | `mintNFT` AI tool — completely free via Helius API |

> **Jupiter devnet note:** `api.jup.ag` operates on mainnet liquidity only. Devnet swap quotes fail because no real pools exist. The `swapTokens` tool communicates this limitation clearly and suggests using `faucet.circle.com` for devnet USDC instead.

---

## 8. Technical Constraints & Mitigations

### 8.1 Context Window (4,096 tokens)

The Foundation Models on-device LLM supports a 4,096-token context window per session. For a wallet assistant, this is sufficient because:
- Most interactions are single-turn: "check balance" → response
- Tool calls are concise: input parameters + return values
- Multi-turn conversations are bounded (users don't need 50-message wallet chats)

For edge cases, SolMind starts a fresh session when approaching the limit, preserving essential state (connected wallet address) in the new session's instructions.

### 8.2 Model Capabilities

The on-device model excels at intent classification, entity extraction, and text generation — exactly what a wallet assistant needs. It is not suitable for math or logical reasoning, but SolMind handles all calculations in Swift tool code. The model's job is routing, not computing.

### 8.3 Device Requirements

Foundation Models requires Apple Silicon and macOS 26 / iOS 26 / iPadOS 26 / visionOS 26 with Apple Intelligence enabled. As of April 2026, this covers all Macs sold since late 2020, all iPhones from iPhone 15 Pro onward, all iPads with M-series chips, and Apple Vision Pro — a large and growing install base.

### 8.4 Devnet-Only Architecture (Hackathon MVP)

The entire MVP is hardcoded to Solana Devnet. There is no mainnet toggle, no network picker, and no configuration to accidentally use real funds.

**Network enforcement:**
- RPC endpoint is hardcoded to `api.devnet.solana.com` (or Triton One devnet)
- A persistent **⚠️ DEVNET** badge is displayed in the app toolbar on all platforms
- All `TransactionPreview` cards are prefixed with "DEVNET —" 
- Explorer links always include `?cluster=devnet`
- The AI's system instructions explicitly state it operates on devnet with test tokens
- The `getFromFaucet` tool replaces the need for real SOL — users can airdrop 1-2 SOL per request

**Sponsor API devnet/sandbox compatibility:**

| API | Mode | Notes |
|---|---|---|
| Solana RPC | Devnet | Full functionality |
| `requestAirdrop` | Devnet | Free SOL, 1-2 SOL/request, rate-limited |
| Jupiter V6 | **Mainnet only** | Quote/swap API is mainnet-only; devnet has no liquidity pools |
| Helius DAS | Devnet | NFT metadata + `mintCompressedNft` extension |
| Circle USDC Faucet | Devnet | Free USDC at [faucet.circle.com](https://faucet.circle.com) |
| MoonPay | Sandbox | Test card numbers, no real charges |

This architecture ensures safe, risk-free demos and eliminates any possibility of financial loss during the hackathon.

---

## 9. Competitive Landscape

| Project | AI Location | Platform | Wallet | Privacy |
|---|---|---|---|---|
| Cloud AI wallet bots | Remote servers | Web | Varies | Low — intents sent to cloud |
| Phantom | None | Extension + mobile | Self-custodial | High — no AI |
| Backpack | None | Extension + mobile | Self-custodial | High — no AI |
| **SolMind** | **On-device** | **Native macOS + iOS + iPadOS + visionOS** | **Self-custodial** | **Highest — AI + keys local** |

SolMind is the first project to combine on-device AI inference with self-custodial wallet operations across all four Apple platforms, including the first-ever Solana wallet experience on Apple Vision Pro.

---

## 10. Roadmap

### Hackathon Scope (5 weeks: April 6 – May 11, 2026)

| Week | Milestone |
|---|---|
| 1 | macOS project scaffold, Foundation Models session, BalanceTool + PriceTool on devnet |
| 2 | Privy wallet integration, Phantom extension bridge, SendTool, polished chat UI |
| 3 | SwapTool (Jupiter), NFTTool (Helius), guided generation previews, iPadOS multi-column layout |
| 4 | iOS compact layout, visionOS spatial window + volumetric transaction cards, MoonPay on-ramp, Phantom deeplinks, error handling |
| 5 | Demo recording (macOS primary + iPadOS/visionOS clips), submission, edge case testing, build distribution |

### Post-Hackathon Vision

- **Mainnet launch** with enhanced security audit
- **Siri Shortcuts integration** via App Intents ("Hey Siri, what's my SOL balance?")
- **Immersive visionOS mode** — full spatial environment for portfolio visualization and NFT gallery
- **Multi-chain expansion** (Ethereum L2s via same tool-calling pattern)
- **Transaction simulation** before signing (Helius)
- **DeFi strategies** — "Stake my SOL for the best yield" with guided comparison
- **watchOS companion** — balance glances and transaction notifications on Apple Watch

---

## 11. Conclusion

SolMind demonstrates that the convergence of on-device AI and self-custodial crypto is not only possible but produces a strictly superior user experience and privacy model compared to cloud-based alternatives. By building on Apple's Foundation Models framework and Solana's high-performance blockchain, SolMind makes interacting with DeFi as simple as sending a text message — whether you're at your Mac, on your iPhone, relaxing with your iPad, or immersed in Apple Vision Pro — without sacrificing a single byte of privacy. This devnet MVP proves the concept end-to-end, with a built-in faucet for instant onboarding and all sponsor APIs running in sandbox mode for safe, risk-free testing.

---

*SolMind is built for the [Colosseum Frontier Hackathon](https://colosseum.com/frontier) (April 6 – May 11, 2026). All development targets Solana Devnet with sponsor APIs in sandbox/test mode. No real funds are used.*
