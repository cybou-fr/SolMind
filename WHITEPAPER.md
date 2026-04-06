# SolMind: On-Device AI Meets Self-Custodial Finance

**A Whitepaper for the Colosseum Frontier Hackathon 2026**

---

## Abstract

SolMind is a native multiplatform wallet application (macOS, iOS, iPadOS, visionOS) that combines Apple's Foundation Models framework with the Solana blockchain to deliver a natural-language interface for decentralized finance. By leveraging an on-device large language model with tool calling capabilities, SolMind enables users to execute blockchain operations — checking balances, sending tokens, swapping assets, viewing NFTs, and requesting faucet airdrops — through conversational prompts, while ensuring that all AI inference happens locally. No financial intent data, no portfolio information, and no transaction details ever leave the user's device during AI processing. SolMind runs natively on Mac, iPhone, iPad, and Apple Vision Pro from a single shared codebase. **This hackathon MVP operates exclusively on Solana Devnet with all sponsor APIs in sandbox/test mode.**

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
┌──────────────────────────────────────────────────┐
│              SolMind Application                  │
│  SwiftUI · macOS / iOS / iPadOS / visionOS        │
├──────────────────────────────────────────────────┤
│                                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │     Apple Foundation Models (On-Device)      │  │
│  │                                              │  │
│  │  SystemLanguageModel.default                 │  │
│  │  LanguageModelSession(instructions:)         │  │
│  │                                              │  │
│  │  Tool Calling ──┬── BalanceTool              │  │
│  │                 ├── FaucetTool               │  │
│  │                 ├── SendTool                 │  │
│  │                 ├── SwapTool                 │  │
│  │                 ├── PriceTool                │  │
│  │                 ├── NFTTool                  │  │
│  │                 ├── TransactionHistoryTool   │  │
│  │                 └── OnRampTool (sandbox)     │  │
│  └──────────────────┬──────────────────────────┘  │
│                     │                             │
│  ┌──────────────────┴──────────────────────────┐  │
│  │           Wallet Abstraction Layer           │  │
│  │                                              │  │
│  │  Privy Swift SDK (embedded wallet)           │  │
│  │  Phantom (browser ext / deeplinks)           │  │
│  │  Keychain + iCloud sync                      │  │
│  └──────────────────┬──────────────────────────┘  │
│                     │                             │
│  ┌──────────────────┴──────────────────────────┐  │
│  │           External Service Layer             │  │
│  │                                              │  │
│  │  Solana JSON-RPC — Devnet (Triton One)       │  │
│  │  Solana Faucet — Devnet airdrop              │  │
│  │  Jupiter V6 API — Devnet (DEX aggregation)   │  │
│  │  Helius DAS API — Devnet (token/NFT data)    │  │
│  │  MoonPay SDK — Sandbox (fiat on/off ramp)    │  │
│  └─────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### 3.2 Foundation Models Integration

The Foundation Models framework provides three capabilities that map directly to wallet operations:

#### 3.2.1 Text Generation & Understanding

The on-device LLM interprets user intent from natural language. A `LanguageModelSession` is initialized with system-level `Instructions` that define the assistant's role and constraints:

```swift
let session = LanguageModelSession(instructions: Instructions("""
    You are SolMind, a Solana wallet assistant running on DEVNET. Help the 
    user manage their crypto assets. All tokens are devnet test tokens with 
    no real value. Use the available tools to check balances, request free 
    SOL from the faucet, send tokens, swap tokens, check prices, and view 
    NFTs. Always show a transaction preview before executing any 
    state-changing operation. Never fabricate wallet addresses or balances 
    — always call the appropriate tool. When a user's wallet is empty, 
    suggest using the faucet to get free devnet SOL.
"""))
```

#### 3.2.2 Tool Calling

Each blockchain operation is encapsulated as a `Tool` conformance. When the user says "send 5 SOL to alice.sol," the model identifies that the `sendTokens` tool should be invoked, extracts the parameters (recipient: "alice.sol", amount: 5.0, tokenMint: nil), and calls the tool. The tool's return value is fed back to the model for response generation.

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

#### 3.2.3 Guided Generation

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

SolMind supports two wallet strategies to cover both new and existing users:

| Strategy | Provider | Platform | Use Case |
|---|---|---|---|
| Embedded wallet | Privy Swift SDK | macOS + iOS + iPadOS + visionOS | New users; social login, no seed phrase |
| External wallet | Phantom extension | macOS | Existing crypto users |
| External wallet | Phantom deeplinks | iOS / iPadOS | Existing crypto users on mobile/tablet |
| External wallet | Phantom via iPhone handoff | visionOS | Existing crypto users on Vision Pro |

Wallet sessions are persisted via Apple Keychain with optional iCloud sync, enabling seamless handoff across a user's Mac, iPhone, iPad, and Vision Pro.

### 3.4 External Services (Devnet / Sandbox)

All external services are configured for devnet or sandbox mode. No real funds or mainnet endpoints are used.

| Service | Purpose | Integration | Mode |
|---|---|---|---|
| Solana JSON-RPC (Triton One) | Balance queries, transaction submission | Direct HTTP | **Devnet** |
| Solana Faucet | Free SOL for testing via `requestAirdrop` | Built-in RPC | **Devnet** |
| Jupiter V6 API | DEX aggregation for token swaps | REST API | **Devnet** |
| Helius DAS API | Token metadata, NFT data, compressed NFTs | REST API | **Devnet** |
| MoonPay SDK | Fiat on-ramp simulation (test cards) | Native SDK | **Sandbox** |
| Phantom | Wallet connection | Extension / deeplinks | **Devnet-aware** |
| Privy | Embedded wallet auth | Swift SDK | **Testnet config** |

### 3.5 Multiplatform Code Sharing

```
SolMind/
├── SolMindApp/              # Thin app targets (per-platform)
│   ├── macOS/               # Window config, menu bar, toolbar
│   ├── iOS/                 # Adaptive navigation, haptics
│   ├── visionOS/            # Spatial scenes, ornaments, volumes
│   └── Shared/              # App entry point, scene definition
├── Packages/
│   ├── SolMindCore/         # 100% shared: AI, wallet, Solana, services
│   └── SolMindUI/           # 95% shared: chat UI, cards, portfolio, spatial views
```

Platform-specific code is limited to `#if os(macOS)` / `#if os(iOS)` / `#if os(visionOS)` branches for window management, navigation style, spatial UI, and wallet connection method. iPadOS shares the iOS target with adaptive layout using `horizontalSizeClass`. All business logic, AI tools, and Solana interactions are fully shared across all four platforms.

---

## 4. Privacy Model

SolMind's privacy guarantee rests on a simple architectural fact: **the AI model runs entirely on-device.**

| Data | Where it's processed | Leaves device? |
|---|---|---|
| User prompts ("send 5 SOL to alice.sol") | On-device Foundation Models | No |
| AI inference & tool selection | On-device Foundation Models | No |
| Wallet private keys | Privy secure enclave / Keychain | No |
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

When using Privy embedded wallets, private keys are managed in the secure enclave and never exposed to the AI model or application code. When using Phantom, signing happens in the external application.

---

## 6. User Experience

### 6.1 Onboarding (30 seconds)

1. Open SolMind — **⚠️ DEVNET** badge visible in toolbar
2. Sign in with Apple / Google / email (Privy handles auth)
3. Wallet is created automatically on devnet — no seed phrase step
4. AI suggests: "Want me to get you some free devnet SOL from the faucet?"
5. Start testing: send, swap, check NFTs — all on devnet with test tokens

### 6.2 Example Interactions

**Balance check:**
> "How much SOL do I have?"
> → AI calls `getBalance` → "You have 12.45 SOL (devnet, ~$1,580 equivalent)"

**Faucet airdrop:**
> "I need some SOL to test with"
> → AI calls `getFromFaucet` → "Airdropped 1 SOL to your devnet wallet. Balance is now 13.45 SOL."

**Token transfer:**
> "Send 100 USDC to bob.sol"
> → AI calls `sendTokens` → preview card: "⚠️ DEVNET — Send 100 USDC to bob.sol" → user confirms → "Sent! TX: 5xA3..."

**Swap:**
> "Swap all my BONK to SOL"
> → AI calls `getBalance` for BONK → calls `swapTokens` via Jupiter devnet → preview → confirm → done

**Portfolio overview:**
> "Show me everything I have"
> → AI calls `getBalance` (all tokens) + `getNFTs` → renders portfolio view

**Fiat on-ramp:**
> "I want to buy $200 worth of SOL"
> → AI calls `buyWithFiat` → MoonPay sandbox flow opens → simulated purchase
> (Or: "Just give me free devnet SOL" → AI calls `getFromFaucet`)

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
- Privy embedded wallet is the primary wallet method (no browser extension on visionOS); connect Phantom via universal link handoff to companion iPhone
- Foundation Models runs natively on Vision Pro's M-series chip — same on-device privacy guarantee

---

## 7. Sponsor Integrations

SolMind integrates multiple Colosseum Frontier Hackathon sponsors:

| Sponsor | Integration | Depth |
|---|---|---|
| **Phantom** | Wallet connection — browser extension bridge (macOS), universal links (iOS/iPadOS), iPhone handoff (visionOS) | Core |
| **Privy** | Embedded wallet creation + social auth via Swift SDK (all platforms) | Core |
| **MoonPay** | Fiat on/off ramp as an AI-callable tool | Core |
| **Coinbase** | Alternative fiat on-ramp via Coinbase Pay | Secondary |
| **Squads / Altitude** | Multisig wallet creation: "Create a 2-of-3 with these addresses" | Secondary |
| **Reflect** | Portfolio performance data source | Secondary |

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
| Jupiter V6 | Devnet | Swap routes available for major devnet tokens |
| Helius DAS | Devnet | Devnet API key, token/NFT metadata |
| Phantom | Devnet-aware | Detects cluster from transaction |
| Privy | Testnet | Embedded wallets work on devnet |
| MoonPay | Sandbox | Test card numbers, no real charges |
| Coinbase Pay | Sandbox | Test mode API keys |

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
