# SolMind

> **AI-native Solana wallet powered by Apple's on-device Foundation Models.**

Built for the [Colosseum Frontier Hackathon](https://colosseum.com/frontier) (April 6 – May 11, 2026).

---

## What is SolMind?

SolMind is a native macOS + iOS + iPadOS + visionOS wallet that lets you interact with Solana entirely through natural language. It uses Apple's **Foundation Models** framework — the on-device LLM behind Apple Intelligence — with **Tool Calling** to execute real blockchain operations. Your financial data and intent never leave your device.

> **⚠️ This hackathon MVP runs exclusively on Solana Devnet. All tokens are test tokens with no real value.**

```
You:  "Send 0.5 SOL to 3A5vT2..."
AI:   → validates address → builds transaction → shows preview card
You:  [Confirm]
AI:   "⚠️ DEVNET: Transaction sent! TX: 4xK2...9fR3"
```

## Key Features

- **Natural language wallet** — chat to check balances, send tokens, swap, view NFTs
- **100% on-device AI** — Foundation Models runs locally on Apple Silicon. Zero data leakage.
- **Guided generation** — transactions produce typed Swift structs (`TransactionPreview`) for safe confirmation
- **10 AI Tools** — Balance, Faucet, Send, Swap, Price, NFTs, MintNFT, CreateToken, Transaction History, MoonPay on-ramp
- **Mint compressed NFTs** — one command mints a cNFT on devnet via Helius (fee-free for the user)
- **Create SPL tokens** — deploy a brand-new fungible token with custom name/symbol/supply in natural language
- **Devnet-only MVP** — persistent ⚠️ DEVNET badge; all APIs in sandbox/devnet mode
- **Faucet built-in** — say "give me some SOL" and the AI airdrops free devnet SOL; Circle USDC faucet also linked
- **Truly multiplatform** — macOS 26 primary + iOS 26 + iPadOS 26 + visionOS 26, single codebase
- **Self-custodial multi-wallet** — generate unlimited Ed25519 keypairs; each stored separately in Apple Keychain; switch or delete at any time
- **Live network stats bar** — compact bar shows real-time SOL price (Jupiter), current epoch + progress, and live TPS fetched from Solana RPC; auto-refreshes every 60 seconds
- **Contextual AI suggestions** — keyword-driven engine surfaces 3–4 relevant follow-up chips after every AI response
- **Deep Solana knowledge** — compressed ecosystem knowledge base (DeFi, NFTs, staking, wallets) injected into the AI system prompt; network stats context prepended to every new session
- **Portfolio USD values** — total portfolio value, per-token USD values, and recent transaction history in the Portfolio tab
- **Markdown AI responses** — bold, italic, and inline code rendered natively in chat bubbles via `AttributedString`
- **AI response time** — response latency shown in toolbar (e.g., "1.3s") for transparency
- **Auto-refresh after transactions** — portfolio balance updates automatically 3–6 seconds after any AI-executed send, swap, faucet, or token creation
- **Network resilience** — RPC requests retry up to 3× with exponential backoff on transient network errors
- **iOS haptic feedback** — success haptic on transaction confirm, light tap on cancel
- **Tap-to-copy addresses** — wallet address in Portfolio and sidebar copies to clipboard with a 2-second checkmark confirmation
- **Message context menu** — long-press any chat bubble to copy message text
- **Personalized empty state** — new chat screen shows live wallet balance, status indicator, and feature highlights

## Architecture

```
┌────────────────────────────────────────────────────┐
│          Multiplatform App (SwiftUI)               │
│   macOS 26 · iOS 26 · iPadOS 26 · visionOS 26      │
│                                                    │
│  SolanaStatsBar ── SolanaStatsViewModel            │
│  Suggestion chips ── SuggestionEngine              │
├────────────────────────────────────────────────────┤
│  Apple Foundation Models (on-device LLM)           │
│  LanguageModelSession + Tool Calling               │
│  System prompt: AIInstructions + SolanaKnowledge   │
│  Context injection: wallet · balance · stats       │
│  → Balance, Faucet, Send, Swap,                    │
│     Price, NFTs, MintNFT, CreateToken,             │
│     TxHistory, OnRamp                              │
├────────────────────────────────────────────────────┤
│  Wallet: Ed25519 keypairs in Apple Keychain        │
├────────────────────────────────────────────────────┤
│  Solana RPC (devnet) · Jupiter · Helius            │
│  MoonPay (sandbox) · PriceService                  │
│  SolanaNetworkService (epoch + TPS)                │
│  UserDefaults (stats + price persistence)          │
└────────────────────────────────────────────────────┘
```

## Project Structure

```
SolMind/
├── SolMind/                        # Single app target (macOS + iOS + visionOS)
│   ├── SolMindApp.swift            # App entry point; injects SolanaStatsViewModel
│   ├── ContentView.swift           # Root navigation (AppDestination enum)
│   ├── Config/                     # SolanaConfig, Secrets
│   ├── Models/                     # ChatMessage, Conversation, TransactionPreview, WalletState
│   ├── AI/
│   │   ├── AISession.swift         # LanguageModelSession wrapper
│   │   ├── AIInstructions.swift    # System prompt + contextBlock() for first-message injection
│   │   ├── SolanaKnowledge.swift   # Compressed Solana ecosystem knowledge base (DeFi, NFTs, staking…)
│   │   ├── SuggestionEngine.swift  # Keyword-driven contextual follow-up suggestion generator
│   │   └── Tools/                  # 10 Tool conformances
│   ├── Solana/                     # SolanaClient, TransactionBuilder (SOL + SPL), Keypair, Base58
│   ├── Wallet/                     # WalletManager (multi-keypair), LocalWallet (Keychain)
│   ├── Services/
│   │   ├── JupiterService.swift    # Jupiter V6 swap quotes & execution
│   │   ├── HeliusService.swift     # DAS API for NFTs & token metadata
│   │   ├── PriceService.swift      # Token price lookups (Jupiter Price API v2, 30s cache)
│   │   ├── SolanaNetworkService.swift  # actor: getEpochInfo + getRecentPerformanceSamples, 2-min cache
│   │   └── ConversationStore.swift # JSON persistence in Application Support
│   ├── Views/
│   │   ├── ChatView.swift          # Chat UI: SolanaStatsBar, suggestion chips, AI stats toolbar
│   │   ├── MessageBubble.swift     # Markdown rendering + TypingIndicator (.task animation)
│   │   ├── SolanaStatsBar.swift    # Compact bar: SOL price · epoch progress · TPS
│   │   ├── TransactionPreviewCard.swift
│   │   ├── PortfolioView.swift     # Total portfolio USD, token list, recent activity
│   │   ├── NFTGalleryView.swift
│   │   ├── WalletSetupView.swift
│   │   ├── WalletPickerView.swift
│   │   ├── ConversationSidebar.swift
│   │   ├── DevnetBadge.swift
│   │   └── PortfolioOrnamentView.swift  # visionOS ornament
│   └── ViewModels/
│       ├── ChatViewModel.swift     # Chat state, context injection, suggestions, response time
│       ├── WalletViewModel.swift   # Wallet state, USD values, total portfolio, tx history
│       └── SolanaStatsViewModel.swift  # @Observable: price + network stats, UserDefaults persistence
├── SolMindTests/                   # Unit tests (Base58, CompactU16, TransactionBuilder)
└── SolMind.xcodeproj/
```

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (macOS 26 primary, iOS 26 / iPadOS 26 / visionOS 26) |
| AI | Apple Foundation Models — `LanguageModelSession` + `@Generable` |
| Crypto | CryptoKit `Curve25519.Signing` (Ed25519) |
| Keychain | Apple Security framework |
| Blockchain | Solana Devnet via public RPC (`api.devnet.solana.com`) |
| Swaps | Jupiter V6 API (devnet) |
| Token/NFT data | Helius DAS API (devnet) |
| Fiat on-ramp | MoonPay (sandbox URL) |
| Persistence | JSON files in Application Support (`ConversationStore`); `UserDefaults` for network stats + SOL price (cold-launch display) |
| Dependencies | **Zero** — no third-party Swift packages |

## AI Tools

| Tool | What it does |
|---|---|
| `getBalance` | SOL and SPL token balances (devnet) |
| `getFromFaucet` | Airdrop free devnet SOL; falls back to Circle USDC faucet URL if rate-limited |
| `sendTokens` | Send SOL to a base58 address with preview → confirm flow |
| `swapTokens` | Swap tokens via Jupiter DEX; notes devnet liquidity limitations |
| `getPrice` | Current token prices (Jupiter Price API v2, 30s cache) |
| `getNFTs` | List wallet NFTs via Helius DAS API (devnet) |
| `mintNFT` | Mint a compressed NFT on devnet via Helius — **fee-free for the user** |
| `createToken` | Create a new SPL token with custom name/symbol/supply/decimals (~0.005 SOL for rent) |
| `getTransactionHistory` | Recent transactions from devnet |
| `buyWithFiat` | Opens MoonPay sandbox widget in browser |

## Platform Adaptations

| Platform | Navigation | Extras |
|---|---|---|
| **macOS** | `NavigationSplitView` — sidebar + detail | ⌘N new chat, ⌘Enter send, ⌘K new chat, Wallets row in sidebar |
| **iOS** | `TabView` — Chat / Portfolio / NFTs / Wallets | Keyboard-safe input via `.safeAreaInset` |
| **iPadOS** | `NavigationSplitView` (inherits macOS) | Adaptive column visibility |
| **visionOS** | `NavigationSplitView` + ornament | `PortfolioOrnamentView` with `.glassBackgroundEffect()` |

## Requirements

- **macOS 26** (Apple Silicon), **iOS 26**, **iPadOS 26**, or **visionOS 26**
- Apple Intelligence enabled in Settings
- Xcode 26+
- Runs on **Solana Devnet** — no real funds needed; use the built-in faucet

## Getting Started

```bash
git clone https://github.com/<your-username>/SolMind.git
cd SolMind

# Add your API keys (copy from example):
cp SolMind/Config/Secrets.example.swift SolMind/Config/Secrets.swift
# Edit Secrets.swift with your Helius devnet key and MoonPay sandbox key

open SolMind.xcodeproj
# ⌘R to build and run on macOS
# App connects to Solana Devnet automatically
# Say "give me some devnet SOL" to fund your wallet
```

## API Keys

| Service | Key type | Free tier |
|---|---|---|
| [Helius](https://dev.helius.xyz) | Devnet API key | ✅ 100K credits/month |
| [MoonPay](https://dashboard.moonpay.com) | Sandbox key | ✅ Free |
| Solana RPC | None (public devnet) | ✅ |
| Jupiter API | None | ✅ |

## Security Model

- **AI inference is on-device.** No API key for AI. No telemetry on financial intent.
- **Private keys never leave the device.** Each keypair stored under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; keyed by its own base58 public key.
- **Confirmation required for all state changes.** Every send/swap shows a `TransactionPreviewCard` before execution.
- **Suspicious AI responses are blocked.** Responses combining a solicitation verb ("enter your", "provide your", etc.) with a credential noun ("private key", "seed phrase", etc.) are intercepted and replaced with a security warning.
- **Address validation before use.** All addresses are Base58-decoded and checked for 32-byte length.
- **AISession task cancellation.** Streaming tasks are cancelled when the consumer stops, preventing orphaned `LanguageModelSession` references.

## Devnet Token Ecosystem

| Token | Devnet Availability | How to Get |
|---|---|---|
| **SOL** | ✅ Native | `getFromFaucet` AI tool, or [faucet.solana.com](https://faucet.solana.com) |
| **USDC** | ✅ Circle devnet mint (`4zMMC9...`) | [faucet.circle.com](https://faucet.circle.com) |
| **Custom tokens** | ✅ Create on demand | `createToken` AI tool — deploys new SPL token in seconds |
| **NFTs** | ✅ Compressed NFTs via Helius | `mintNFT` AI tool — completely free |
| **Swaps (USDC↔SOL)** | ⚠️ Limited | Jupiter `api.jup.ag` is mainnet-only; devnet swaps will fail with no-liquidity |

## Hackathon Sponsors Used

| Sponsor | How |
|---|---|
| **Jupiter** | Token swap quotes + execution (`swapTokens` AI tool); price oracle |
| **Helius** | NFT metadata via DAS API (`getNFTs`); compressed NFT minting (`mintNFT`) |
| **MoonPay** | Fiat on-ramp sandbox widget (`buyWithFiat` AI tool) |

## License

MIT

---

*Built for the [Colosseum Frontier Hackathon](https://colosseum.com/frontier) 2026.*
