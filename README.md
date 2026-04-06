# SolMind

> **AI-native Solana wallet powered by Apple's on-device Foundation Models.**

Built for the [Colosseum Frontier Hackathon](https://colosseum.com/frontier) (April 6 – May 11, 2026).

---

## What is SolMind?

SolMind is a native macOS + iOS + iPadOS + visionOS wallet that lets you interact with Solana entirely through natural language. It uses Apple's **Foundation Models** framework — the on-device LLM behind Apple Intelligence — with **Tool Calling** to execute real blockchain operations. Your financial data and intent never leave your device.

> **⚠️ This hackathon MVP runs exclusively on Solana Devnet. All tokens are test tokens with no real value.**

```
You:  "Send 5 USDC to alice.sol"
AI:   → resolves alice.sol → builds transaction → shows preview card
You:  [Confirm]
AI:   "Sent! TX: 4xK2...9fR3"
```

## Key Features

- **Natural language wallet** — chat to check balances, send tokens, swap, view NFTs
- **100% on-device AI** — Foundation Models runs locally on Apple Silicon. Zero data leakage.
- **Guided generation** — transactions produce typed Swift structs (`TransactionPreview`) for safe confirmation
- **Tool Calling** — the AI invokes real Solana operations (balance, send, swap, price, NFTs, faucet airdrop)
- **Devnet-only MVP** — persistent ⚠️ DEVNET badge, all sponsor APIs in sandbox/devnet mode
- **Faucet built-in** — say "give me some SOL" and the AI airdrops free devnet SOL to your wallet
- **macOS-first, truly multiplatform** — native desktop + iOS + iPadOS + visionOS from a single SwiftUI codebase
- **Multiple wallet options** — Privy embedded wallet (social login, no seed phrase) or connect Phantom

## Architecture

```
┌───────────────────────────────────────────────┐
│       Multiplatform App (SwiftUI)             │
│  macOS 26 · iOS 26 · iPadOS 26 · visionOS 26  │
├───────────────────────────────────────────────┤
│  Apple Foundation Models (on-device LLM)      │
│  Tool Calling → Balance, Send, Swap,          │
│                 Price, NFTs, OnRamp           │
├───────────────────────────────────────────────┤
│  Wallet: Privy SDK + Phantom                  │
├───────────────────────────────────────────────┤
│  Solana RPC · Jupiter · Helius · MoonPay      │
└───────────────────────────────────────────────┘
```

## Project Structure

```
SolMind/
├── SolMindApp/
│   ├── macOS/              # macOS entry point & window config
│   ├── iOS/                # iOS/iPadOS entry point
│   ├── visionOS/           # visionOS entry point & spatial scenes
│   └── Shared/             # Shared App lifecycle
├── Packages/
│   ├── SolMindCore/        # AI session, tools, Solana client, services
│   └── SolMindUI/          # Shared SwiftUI views (chat, cards, portfolio, spatial)
└── README.md
```

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (macOS 26 primary, iOS 26 / iPadOS 26 / visionOS 26) |
| AI | Apple Foundation Models framework |
| Wallet | Privy Swift SDK + Phantom |
| Blockchain | Solana Devnet RPC via Triton One |
| Swaps | Jupiter V6 API (devnet) |
| Token/NFT data | Helius DAS API (devnet) |
| Faucet | Solana `requestAirdrop` (devnet) |
| Fiat on-ramp | MoonPay SDK (sandbox mode) |

## AI Tools

The Foundation Models `Tool` protocol powers each blockchain operation:

| Tool | What it does |
|---|---|
| `getBalance` | SOL and SPL token balances (devnet) |
| `getFromFaucet` | Airdrop free devnet SOL to wallet |
| `sendTokens` | Send SOL/tokens to address or .sol domain |
| `swapTokens` | Swap tokens via Jupiter DEX (devnet) |
| `getPrice` | Current token prices |
| `getNFTs` | List wallet NFTs (devnet) |
| `buyWithFiat` | MoonPay fiat on-ramp (sandbox mode) |
| `getTransactionHistory` | Recent transactions (devnet) |

## Requirements

- **macOS 26** (Apple Silicon), **iOS 26**, **iPadOS 26**, or **visionOS 26**
- Apple Intelligence enabled in Settings
- Xcode 26+
- Runs on **Solana Devnet** — no real funds needed, use the built-in faucet tool

## Getting Started

```bash
git clone https://github.com/<your-username>/SolMind.git
cd SolMind
open SolMind.xcodeproj
# ⌘R to build and run on macOS
# App connects to Solana Devnet automatically
# Say "give me some devnet SOL" to fund your wallet via faucet
```

## Hackathon Sponsors Used

- **Phantom** — wallet connection (browser extension on macOS, deeplinks on iOS/iPadOS)
- **Privy** — embedded wallet with social login (all platforms including visionOS)
- **MoonPay** — fiat on/off ramp (sandbox mode)
- **Coinbase** — alternative on-ramp (sandbox mode)
- **Squads / Altitude** — multisig support
- **Reflect** — portfolio data

## Why macOS-First & Truly Multiplatform?

Almost zero native macOS Solana wallets exist — and zero on visionOS. macOS-first means faster development (`⌘R` runs natively), trivial screen recording for the demo video, and judges can download the `.app` and try it themselves — no TestFlight needed. The same SwiftUI code runs on iOS, iPadOS, and visionOS with platform-specific adaptations:

| Platform | Highlights |
|---|---|
| **macOS** | Desktop window + sidebar, menu bar widget, keyboard-first |
| **iOS** | Compact layout, haptic confirmations |
| **iPadOS** | Multi-column layout, Stage Manager, Apple Pencil, keyboard/trackpad |
| **visionOS** | Spatial windows, volumetric transaction cards, gaze confirmation |

## License

MIT

---

*Built for the [Colosseum Frontier Hackathon](https://colosseum.com/frontier) 2026.*
