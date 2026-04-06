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
- **8 AI Tools** — Balance, Faucet, Send, Swap, Price, NFTs, Transaction History, MoonPay on-ramp
- **Devnet-only MVP** — persistent ⚠️ DEVNET badge; all APIs in sandbox/devnet mode
- **Faucet built-in** — say "give me some SOL" and the AI airdrops free devnet SOL
- **Truly multiplatform** — macOS 26 primary + iOS 26 + iPadOS 26 + visionOS 26, single codebase
- **Self-custodial** — Ed25519 keypair generated on-device, stored in Apple Keychain

## Architecture

```
┌───────────────────────────────────────────────┐
│       Multiplatform App (SwiftUI)             │
│  macOS 26 · iOS 26 · iPadOS 26 · visionOS 26  │
├───────────────────────────────────────────────┤
│  Apple Foundation Models (on-device LLM)      │
│  LanguageModelSession + Tool Calling          │
│  → Balance, Faucet, Send, Swap,               │
│     Price, NFTs, TxHistory, OnRamp           │
├───────────────────────────────────────────────┤
│  Wallet: Ed25519 keypair in Apple Keychain    │
├───────────────────────────────────────────────┤
│  Solana RPC (devnet) · Jupiter · Helius       │
│  MoonPay (sandbox) · PriceService             │
└───────────────────────────────────────────────┘
```

## Project Structure

```
SolMind/
├── SolMind/                  # Single app target (macOS + iOS + visionOS)
│   ├── SolMindApp.swift      # App entry point
│   ├── ContentView.swift     # Root navigation (AppDestination enum)
│   ├── Config/               # SolanaConfig, Secrets
│   ├── Models/               # ChatMessage, Conversation, TransactionPreview, WalletState
│   ├── AI/
│   │   ├── AISession.swift   # LanguageModelSession wrapper
│   │   ├── AIInstructions.swift
│   │   └── Tools/            # 8 Tool conformances
│   ├── Solana/               # SolanaClient, TransactionBuilder, Keypair, Base58
│   ├── Wallet/               # WalletManager, LocalWallet (Keychain)
│   ├── Services/             # JupiterService, HeliusService, PriceService, ConversationStore
│   ├── Views/                # ChatView, MessageBubble, TransactionPreviewCard,
│   │                         # PortfolioView, NFTGalleryView, WalletSetupView,
│   │                         # ConversationSidebar, DevnetBadge, PortfolioOrnamentView
│   └── ViewModels/           # ChatViewModel, WalletViewModel
├── SolMindTests/             # Unit tests (Base58, TransactionBuilder, RPCResponse)
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
| Persistence | JSON files in Application Support (`ConversationStore`) |
| Dependencies | **Zero** — no third-party Swift packages |

## AI Tools

| Tool | What it does |
|---|---|
| `getBalance` | SOL and SPL token balances (devnet) |
| `getFromFaucet` | Airdrop free devnet SOL; falls back to web faucet URLs if rate-limited |
| `sendTokens` | Send SOL to a base58 address with preview → confirm flow |
| `swapTokens` | Swap tokens via Jupiter DEX (devnet) with preview → confirm |
| `getPrice` | Current token prices (Jupiter Price API v2, 30s cache) |
| `getNFTs` | List wallet NFTs via Helius DAS API (devnet) |
| `getTransactionHistory` | Recent transactions from devnet |
| `buyWithFiat` | Opens MoonPay sandbox widget in browser |

## Platform Adaptations

| Platform | Navigation | Extras |
|---|---|---|
| **macOS** | `NavigationSplitView` — sidebar + detail | ⌘N new chat, ⌘Enter send, ⌘K clear |
| **iOS** | `TabView` — Chat / Portfolio / NFTs | Keyboard-safe input |
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
- **Private key never leaves the device.** Stored in `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` Keychain.
- **Confirmation required for all state changes.** Every send/swap shows a `TransactionPreviewCard` before execution.
- **Suspicious AI responses are blocked.** Any AI response mentioning "private key" or "seed phrase" is intercepted.
- **Address validation before use.** All addresses are Base58-decoded and checked for 32-byte length.

## Hackathon Sponsors Used

| Sponsor | How |
|---|---|
| **Jupiter** | Token swap quotes + execution (`swapTokens` AI tool) |
| **Helius** | NFT metadata via DAS API (`getNFTs` AI tool + NFTGalleryView) |
| **MoonPay** | Fiat on-ramp sandbox widget (`buyWithFiat` AI tool) |

## License

MIT

---

*Built for the [Colosseum Frontier Hackathon](https://colosseum.com/frontier) 2026.*
