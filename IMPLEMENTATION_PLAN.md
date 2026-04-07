# SolMind — Detailed Implementation Plan

> **Status:** Post-submission polish. Phases 0–6 complete. Reliability, UX, and resilience improvements in progress.
> **Targets:** macOS 26.4 (primary), iOS 26.4, iPadOS 26.4, visionOS 26.4
> **Network:** Solana Devnet only
> **Bundle ID:** `fr.cybou.SolMind`
> **Team:** `9W74HUTJJL`
> **Last updated:** April 7, 2026 (network retry, auto-balance refresh after tools, haptic feedback, tap-to-copy address, message context menu, enhanced empty states, Sendable RPC models, isSuspiciousResponse improved, dual TypingIndicator fix, AISession stream cancellation, PriceService.shared singleton)

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Target Architecture](#2-target-architecture)
3. [Phase 0 — Project Restructure & Foundation](#phase-0--project-restructure--foundation-day-1-2)
4. [Phase 1 — Core AI Chat (Foundation Models)](#phase-1--core-ai-chat-foundation-models-days-3-5)
5. [Phase 2 — Solana RPC Client & Wallet](#phase-2--solana-rpc-client--wallet-days-6-10)
6. [Phase 3 — AI Tool Implementations](#phase-3--ai-tool-implementations-days-11-16)
7. [Phase 4 — DeFi & Sponsor Integrations](#phase-4--defi--sponsor-integrations-days-17-22)
8. [Phase 5 — Platform Polish & visionOS](#phase-5--platform-polish--visionos-days-23-28)
9. [Phase 6 — Demo, Submission & QA](#phase-6--demo-submission--qa-days-29-35)
10. [File-by-File Implementation Map](#file-by-file-implementation-map)
11. [Dependency Graph](#dependency-graph)
12. [External Dependencies](#external-dependencies)
13. [API Keys & Configuration](#api-keys--configuration)
14. [Testing Strategy](#testing-strategy)
15. [Risk Register](#risk-register)

---

## 1. Current State Assessment

### What exists (Day 2+)
| Item | Status |
|---|---|
| Xcode project (`SolMind.xcodeproj`) | ✅ Multiplatform (macOS + iOS + visionOS), auto file-sync |
| `SolMindApp.swift` | ✅ Rewritten — WalletViewModel + ChatViewModel + SolanaStatsViewModel injected as environments |
| `ContentView.swift` | ✅ AppDestination enum, NavigationSplitView (macOS/visionOS), TabView (iOS) |
| Platform targets | ✅ macOS 26.4, iOS 26.4, visionOS 26.4 |
| Foundation Models integration | ✅ AISession, AIInstructions, streaming, context-window recovery |
| AI context injection | ✅ First-message context block: wallet address · SOL balance · USD value · token count · network stats · knowledge hint |
| Solana knowledge base | ✅ `SolanaKnowledge.swift` — compressed DeFi/NFTs/staking/wallets knowledge injected into system prompt |
| Contextual suggestions | ✅ `SuggestionEngine.swift` — keyword-matched chips after every AI response; cleared on send |
| Solana network stats | ✅ `SolanaNetworkService.swift` (actor, 2-min cache): epoch info + TPS via `getEpochInfo` + `getRecentPerformanceSamples` |
| Stats ViewModel | ✅ `SolanaStatsViewModel.swift` (@Observable, UserDefaults persistence for cold-launch display) |
| Stats bar UI | ✅ `SolanaStatsBar.swift` — compact 28pt bar: SOL price · epoch progress capsule · TPS |
| Markdown AI responses | ✅ `AttributedString(markdown:options:.inlineOnlyPreservingWhitespace)` in MessageBubble |
| TypingIndicator (fixed) | ✅ `.task` loop with `Task.sleep(for:.milliseconds(400))` replaces broken `withAnimation(.repeatForever())` |
| Portfolio USD values | ✅ `WalletViewModel`: `solUSDValue`, `totalPortfolioUSD`, per-token USD, `recentTransactions` |
| Portfolio recent activity | ✅ `PortfolioView`: total value header, Recent Activity section with explorer links |
| AI response time tracking | ✅ `lastResponseTime: TimeInterval?` in ChatViewModel; displayed in ChatView toolbar |
| Real-time streaming | ✅ `collectStream()` updates message content on each chunk |
| Solana RPC client | ✅ SolanaClient (actor): balance, airdrop, sendTransaction, getSignatures |
| Wallet (local keypair) | ✅ Ed25519 via CryptoKit, **multi-keypair** Keychain (LocalWallet), WalletManager |
| All 10 AI Tools | ✅ Balance, Faucet, Send, Price, Swap, NFT, MintNFT, CreateToken, TxHistory, OnRamp |
| Chat UI | ✅ ChatView, MessageBubble, TypingIndicator, dynamic suggestion chips |
| Devnet configuration | ✅ SolanaConfig, DevnetBadge in all toolbars |
| Transaction serialization | ✅ TransactionBuilder (SOL transfer wire format) |
| TransactionPreviewCard | ✅ @Generable TransactionPreview, confirm/cancel card |
| Jupiter swap | ✅ JupiterService (quote + swap transaction, URLSession timeout, devnet USDC mint fixed) |
| Helius DAS | ✅ HeliusService (getAssetsByOwner + mintCompressedNft) |
| SPL token creation | ✅ CreateTokenTool + TransactionBuilder.buildCreateMint/buildMintTokens + PDA derivation |
| Compressed NFT minting | ✅ MintNFTTool via Helius cNFT API (fee-free for owner) |
| Devnet USDC faucet | ✅ FaucetTool updated with Circle faucet URL (https://faucet.circle.com) |
| Price service | ✅ PriceService (Jupiter Price API v2, 30s cache) |
| NFT Gallery | ✅ NFTGalleryView with AsyncImage grid |
| Conversation sidebar (macOS) | ✅ ConversationSidebar with totalPortfolioUSD display |
| visionOS ornament | ✅ PortfolioOrnamentView with totalPortfolioUSD + glassBackgroundEffect |
| Conversation persistence | ✅ ConversationStore (JSON files in Application Support) |
| Stats persistence | ✅ SolanaNetworkStats (Codable) + solPrice persisted to UserDefaults |
| iOS Tab navigation | ✅ TabView with Chat / Portfolio / NFTs / Wallets tabs |
| ⌘K new chat shortcut | ✅ Toolbar button + keyboardShortcut in ChatView |
| iOS keyboard docking | ✅ `.safeAreaInset(edge: .bottom)` on iOS |
| Multi-keypair wallets | ✅ Generate, switch, delete; legacy migration; WalletPickerView |
| Unit tests | ✅ Base58 roundtrip/known address, CompactU16, SOL transfer serialization length |
| Phantom deeplinks | ❌ P3 stretch — not implemented |
| Network retry | ✅ `SolanaClient.postRaw` retries up to 3× with 500ms/1000ms backoff on transient URLErrors |
| Auto-balance refresh | ✅ `ChatViewModel.scheduleBalanceRefreshIfNeeded` — detects successful tool responses and refreshes balance (3s send/swap, 6s airdrop) |
| iOS haptic feedback | ✅ `UINotificationFeedbackGenerator` on confirm, `UIImpactFeedbackGenerator(style:.light)` on cancel |
| Tap-to-copy address | ✅ `PortfolioView` + `ConversationSidebar` — 2s animated checkmark confirmation |
| Message copy context menu | ✅ Long-press bubble → "Copy Message" (cross-platform) |
| AISession task leak fix | ✅ `continuation.onTermination` cancels inner Task; `Task.isCancelled` checked in stream loop |
| PriceService singleton | ✅ `PriceService.shared` — prevents duplicate caches across ViewModels |
| Dual TypingIndicator fix | ✅ Removed standalone indicator from ChatView (MessageBubble handles it) |
| Enhanced empty state | ✅ ChatView: live wallet card + feature bullets; PortfolioView: zero-balance onboarding nudge; NFT: improved guidance |
| Sendable RPC models | ✅ All structs in `RPCResponse.swift` + `SignatureStatus`/`AnyCodable` in `SolanaClient.swift` |

### Architecture decision record
> **Flat structure in app target (no Swift Packages for MVP)**  
> `SolMindCore` and `SolMindUI` packages were cut. All code lives directly in the app target for hackathon speed.

> **Local keypair — multi-keypair support**  
> Each keypair is stored as a distinct Keychain item (`kSecAttrAccount` = base58 public key). `LocalWallet.allAddresses()` enumerates all persisted wallets; `LocalWallet.activeAddress` (a `UserDefaults` key) tracks which is active. `WalletManager.createAndActivateWallet()` generates a new keypair and makes it active; `switchWallet(to:)` hot-swaps; `deleteWallet(address:)` auto-selects the next wallet. `WalletPickerView` provides the full UI. Legacy single-key Keychain items (`account = "ed25519-private-key"`) are automatically migrated on first launch.

> **No .sol domain resolution**  
> SNS on-chain resolution was cut. Recipient addresses must be valid base58 Solana addresses. The AI validates with `Base58.isValidAddress()` before attempting any send.

---

## 2. Target Architecture

```
SolMind/
├── SolMind/                          # Main app target
│   ├── SolMindApp.swift              # App entry + WalletVM/ChatVM/SolanaStatsVM environments
│   ├── ContentView.swift             # Root view with NavigationSplitView / TabView
│   ├── Config/
│   │   └── SolanaConfig.swift        # Devnet RPC URLs, network enum
│   ├── Models/
│   │   ├── ChatMessage.swift         # Message model (user/assistant/tool)
│   │   ├── Conversation.swift        # Conversation with message history
│   │   └── WalletState.swift         # Observable wallet state
│   ├── AI/
│   │   ├── AISession.swift           # Foundation Models session manager
│   │   ├── AIInstructions.swift      # System prompt + contextBlock() for first-message injection
│   │   ├── SolanaKnowledge.swift     # ✨ Compressed Solana ecosystem knowledge (DeFi/NFTs/staking)
│   │   ├── SuggestionEngine.swift    # ✨ Keyword-matched follow-up suggestion generator
│   │   └── Tools/
│   │       ├── BalanceTool.swift      # getBalance
│   │       ├── FaucetTool.swift       # getFromFaucet
│   │       ├── SendTool.swift         # sendTokens (TransactionConfirmationHandler)
│   │       ├── SwapTool.swift         # swapTokens (TransactionConfirmationHandler)
│   │       ├── PriceTool.swift        # getPrice
│   │       ├── NFTTool.swift          # getNFTs
│   │       ├── MintNFTTool.swift      # mintNFT via Helius
│   │       ├── CreateTokenTool.swift  # createToken (SPL mint + mintTokens)
│   │       ├── TransactionHistoryTool.swift  # getTransactionHistory
│   │       └── OnRampTool.swift       # buyWithFiat
│   ├── Solana/
│   │   ├── SolanaClient.swift         # JSON-RPC client for devnet
│   │   ├── TransactionBuilder.swift   # Build & serialize transactions
│   │   ├── Keypair.swift              # Ed25519 key management
│   │   └── Models/
│   │       ├── RPCResponse.swift      # RPC response types
│   │       ├── TokenAccount.swift     # SPL token account model
│   │       └── TransactionModel.swift # Transaction data model
│   ├── Wallet/
│   │   ├── WalletManager.swift        # Multi-keypair wallet interface
│   │   └── LocalWallet.swift          # Keychain-stored keypairs (multi-wallet)
│   ├── Services/
│   │   ├── JupiterService.swift       # Jupiter V6 swap quotes & execution
│   │   ├── HeliusService.swift        # DAS API for NFTs & token metadata
│   │   ├── PriceService.swift         # Token price lookups (30s cache)
│   │   ├── SolanaNetworkService.swift # ✨ actor: epoch info + TPS (2-min cache)
│   │   └── ConversationStore.swift    # JSON persistence in Application Support
│   ├── Views/
│   │   ├── ChatView.swift             # Chat UI + SolanaStatsBar + dynamic suggestion chips
│   │   ├── MessageBubble.swift        # Markdown rendering + fixed TypingIndicator
│   │   ├── SolanaStatsBar.swift       # ✨ SOL price · epoch progress · TPS bar
│   │   ├── TransactionPreviewCard.swift # Confirmation card with approve/reject
│   │   ├── PortfolioView.swift        # Total portfolio USD + token list + recent activity
│   │   ├── NFTGalleryView.swift       # NFT grid display
│   │   ├── WalletSetupView.swift      # Onboarding / wallet creation
│   │   ├── WalletPickerView.swift     # Multi-keypair list, generate, switch, delete
│   │   ├── DevnetBadge.swift          # Persistent ⚠️ DEVNET indicator
│   │   ├── PortfolioOrnamentView.swift# visionOS ornament (totalPortfolioUSD)
│   │   └── ConversationSidebar.swift  # macOS sidebar (totalPortfolioUSD)
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift        # Chat state + context injection + suggestions + response time
│   │   ├── WalletViewModel.swift      # Wallet state + USD values + tx history
│   │   └── SolanaStatsViewModel.swift # ✨ @Observable: price + network stats + UserDefaults cache
│   └── Assets.xcassets/
├── SolMindTests/                      # Unit tests (Base58, CompactU16, TransactionBuilder)
│   └── SolMindTests.swift
├── SolMindUITests/
└── SolMind.xcodeproj/
```

> ✨ = Added after initial implementation plan

> **Decision: Flat structure in app target (no Swift Packages for MVP)**
> The original plan called for `SolMindCore` and `SolMindUI` Swift Packages. For a 5-week hackathon with a single developer, this adds overhead (package manifests, target dependencies, access control headaches). All code lives directly in the app target. Refactoring into packages is a post-hackathon task.

---

## Phase 0 — Project Restructure & Foundation ✅ COMPLETE

### Goals
- Remove template boilerplate ✅
- Set up folder structure ✅
- Add devnet configuration ✅
- Verify project builds on macOS ✅

### Tasks

#### 0.1 — Remove SwiftData template code
- [ ] Delete `Item.swift`
- [ ] Remove SwiftData import and `ModelContainer` from `SolMindApp.swift`
- [ ] Remove SwiftData import, `@Query`, and `modelContext` from `ContentView.swift`

#### 0.2 — Create folder structure
Create the following directories inside `SolMind/SolMind/`:
- [ ] `Config/`
- [ ] `Models/`
- [ ] `AI/`
- [ ] `AI/Tools/`
- [ ] `Solana/`
- [ ] `Solana/Models/`
- [ ] `Wallet/`
- [ ] `Services/`
- [ ] `Views/`
- [ ] `ViewModels/`

#### 0.3 — Devnet configuration
Create `Config/SolanaConfig.swift`:
```swift
import Foundation

enum SolanaNetwork {
    static let cluster = "devnet"
    static let rpcURL = URL(string: "https://api.devnet.solana.com")!
    static let wsURL = URL(string: "wss://api.devnet.solana.com")!
    static let explorerBaseURL = "https://explorer.solana.com"
    
    static func explorerURL(signature: String) -> URL {
        URL(string: "\(explorerBaseURL)/tx/\(signature)?cluster=devnet")!
    }
    
    static func explorerURL(address: String) -> URL {
        URL(string: "\(explorerBaseURL)/address/\(address)?cluster=devnet")!
    }
}
```

#### 0.4 — Skeleton App entry point
Rewrite `SolMindApp.swift`:
```swift
import SwiftUI

@main
struct SolMindApp: App {
    @State private var walletViewModel = WalletViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(walletViewModel)
        }
    }
}
```

#### 0.5 — Skeleton ContentView
Rewrite `ContentView.swift` to a placeholder that compiles:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            Text("Conversations")
        } detail: {
            Text("SolMind — Chat will go here")
        }
        #else
        NavigationStack {
            Text("SolMind — Chat will go here")
        }
        #endif
    }
}
```

#### 0.6 — Add Foundation Models framework
- [ ] In Xcode: Target → General → Frameworks → Add `FoundationModels.framework`
- [ ] Verify `import FoundationModels` compiles

#### 0.7 — Add entitlements
- [ ] Enable **Outgoing Connections (Client)** in App Sandbox (needed for RPC calls)
- [ ] Keychain access for wallet key storage

#### 0.8 — Verify build
- [ ] `⌘B` — project must build on macOS 26 with zero errors

### Deliverables
- Clean project structure, no template code
- Compiles on macOS
- Devnet config ready

---

## Phase 1 — Core AI Chat (Foundation Models) ✅ COMPLETE

### Goals
- Foundation Models session with system instructions ✅
- Chat UI with message history ✅
- Streaming text responses ✅
- Tool protocol stubs → all 8 tools implemented in Phase 3 ✅

### Tasks

#### 1.1 — Chat data models
Create `Models/ChatMessage.swift`:
```swift
import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    
    enum Role {
        case user
        case assistant
        case tool(name: String)
        case error
    }
}
```

Create `Models/Conversation.swift`:
```swift
import Foundation

@Observable
class Conversation: Identifiable {
    let id = UUID()
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    
    init(title: String = "New Chat") {
        self.title = title
        self.messages = []
        self.createdAt = Date()
    }
}
```

#### 1.2 — AI session manager
Create `AI/AIInstructions.swift`:
```swift
// System prompt for Foundation Models session
enum AIInstructions {
    static let system = """
    You are SolMind, a Solana wallet assistant running on DEVNET. \
    Help the user manage their crypto assets. All tokens are devnet \
    test tokens with no real value. Use the available tools to check \
    balances, request free SOL from the faucet, send tokens, swap \
    tokens, check prices, and view NFTs. Always show a transaction \
    preview before executing any state-changing operation. Never \
    fabricate wallet addresses or balances — always call the \
    appropriate tool. When a user's wallet is empty, suggest using \
    the faucet to get free devnet SOL.
    """
}
```

Create `AI/AISession.swift`:
```swift
import FoundationModels

@Observable
class AISession {
    private var session: LanguageModelSession?
    
    func initialize(tools: [any Tool]) throws {
        let instructions = Instructions(AIInstructions.system)
        session = LanguageModelSession(
            instructions: instructions,
            tools: tools
        )
    }
    
    func send(_ prompt: String) async throws -> String {
        guard let session else { throw AIError.notInitialized }
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    // Streaming variant
    func stream(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        // Implementation depends on Foundation Models streaming API
    }
}

enum AIError: LocalizedError {
    case notInitialized
    case modelUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notInitialized: "AI session not initialized"
        case .modelUnavailable: "On-device model not available. Enable Apple Intelligence in Settings."
        }
    }
}
```

#### 1.3 — Chat UI
Create `Views/ChatView.swift`:
- ScrollView with LazyVStack of message bubbles
- Text field at bottom with send button
- `⌘Enter` shortcut to send (macOS)
- Auto-scroll to bottom on new messages
- Streaming indicator (typing dots)

Create `Views/MessageBubble.swift`:
- User messages: right-aligned, accent color
- Assistant messages: left-aligned, secondary background
- Tool result messages: compact card style
- Error messages: red tint

Create `Views/DevnetBadge.swift`:
- Orange/yellow badge: "⚠️ DEVNET"
- Always visible in toolbar

#### 1.4 — ChatViewModel
Create `ViewModels/ChatViewModel.swift`:
```swift
@Observable
class ChatViewModel {
    var conversations: [Conversation] = []
    var activeConversation: Conversation?
    var inputText: String = ""
    var isProcessing: Bool = false
    
    private let aiSession = AISession()
    
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userMessage = ChatMessage(role: .user, content: inputText, timestamp: Date(), isStreaming: false)
        activeConversation?.messages.append(userMessage)
        let prompt = inputText
        inputText = ""
        isProcessing = true
        
        do {
            let response = try await aiSession.send(prompt)
            let assistantMessage = ChatMessage(role: .assistant, content: response, timestamp: Date(), isStreaming: false)
            activeConversation?.messages.append(assistantMessage)
        } catch {
            let errorMessage = ChatMessage(role: .error, content: error.localizedDescription, timestamp: Date(), isStreaming: false)
            activeConversation?.messages.append(errorMessage)
        }
        
        isProcessing = false
    }
}
```

#### 1.5 — Wire up ContentView
Replace placeholder ContentView with:
- macOS: `NavigationSplitView` with sidebar (conversation list) + detail (ChatView)
- iOS: `NavigationStack` with ChatView
- Toolbar with DevnetBadge

#### 1.6 — Test AI chat on macOS
- [ ] Verify Foundation Models responds to basic prompts
- [ ] Verify streaming works
- [ ] Verify multi-turn context is maintained
- [ ] Handle "model not available" gracefully

### Deliverables
- Working chat interface on macOS
- Foundation Models responds to natural language
- Messages display correctly
- Devnet badge visible

---

## Phase 2 — Solana RPC Client & Wallet ✅ COMPLETE

### Goals
- JSON-RPC client for Solana devnet ✅
- Local keypair generation & Keychain storage ✅
- Balance queries working ✅
- Faucet airdrop working ✅

### Tasks

#### 2.1 — Solana RPC client
Create `Solana/SolanaClient.swift`:

Implement these RPC methods:
| Method | RPC Call | Purpose |
|---|---|---|
| `getBalance(publicKey:)` | `getBalance` | SOL balance in lamports |
| `getTokenAccountsByOwner(publicKey:)` | `getTokenAccountsByOwner` | SPL token balances |
| `requestAirdrop(to:lamports:)` | `requestAirdrop` | Faucet for devnet SOL |
| `sendTransaction(serialized:)` | `sendTransaction` | Submit signed tx |
| `getRecentBlockhash()` | `getLatestBlockhash` | For transaction building |
| `getSignatureStatuses(signatures:)` | `getSignatureStatuses` | Confirm tx |
| `getTransaction(signature:)` | `getTransaction` | Tx details |
| `getAccountInfo(publicKey:)` | `getAccountInfo` | Generic account data |

Implementation approach:
- Use `URLSession` for HTTP POST to devnet RPC
- JSON-RPC 2.0 request/response encoding via `Codable`
- All methods are `async throws`
- Rate limiting: simple delay between calls to avoid 429s from public devnet endpoint

Create `Solana/Models/RPCResponse.swift`:
```swift
struct RPCRequest<P: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: P
}

struct RPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: T?
    let error: RPCError?
}

struct RPCError: Decodable, LocalizedError {
    let code: Int
    let message: String
    var errorDescription: String? { message }
}
```

#### 2.2 — Ed25519 keypair management
Create `Solana/Keypair.swift`:
- Generate Ed25519 keypair using `CryptoKit` (`Curve25519.Signing`)
- Derive base58 public key (Solana address)
- Store private key in Keychain
- Load from Keychain on app launch
- Base58 encoding/decoding utility

> **Note:** CryptoKit's `Curve25519.Signing` uses Ed25519 which is what Solana uses. No third-party crypto library needed.

#### 2.3 — Base58 encoding
Create a Base58 encoder/decoder. Solana addresses are base58-encoded Ed25519 public keys (32 bytes → 32-44 characters). Implement the Bitcoin-style base58 alphabet (`123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz`).

#### 2.4 — Transaction builder
Create `Solana/TransactionBuilder.swift`:
- Build SOL transfer instruction (System Program `Transfer`)
- Build SPL token transfer instruction (Token Program `Transfer`)
- Serialize transaction in Solana's wire format
- Sign with Ed25519 private key
- Compact format for `sendTransaction` RPC

> **This is the most complex part.** Solana transaction format:
> 1. Signatures array
> 2. Message: header (num_signers, num_read_only_signed, num_read_only_unsigned)
> 3. Account addresses array
> 4. Recent blockhash
> 5. Instructions (program_id_index, account_indices, data)

Implementation strategy:
- Start with SOL transfers only (System Program, instruction index 2)
- Add SPL token transfers in Phase 3
- Use raw byte serialization — no third-party protobuf

#### 2.5 — Wallet manager
Create `Wallet/WalletManager.swift`:
```swift
@Observable
class WalletManager {
    var publicKey: String?
    var isConnected: Bool { publicKey != nil }
    private var keypair: Keypair?
    
    func createWallet() throws {
        // Generate new keypair, store in Keychain
    }
    
    func loadWallet() throws {
        // Load from Keychain
    }
    
    func signTransaction(_ txBytes: Data) throws -> Data {
        // Sign with private key
    }
    
    var displayAddress: String {
        guard let pk = publicKey else { return "Not connected" }
        return "\(pk.prefix(4))...\(pk.suffix(4))"
    }
}
```

Create `Wallet/LocalWallet.swift`:
- Keychain CRUD operations for private key
- Uses `kSecClassGenericPassword` with service `"fr.cybou.SolMind.wallet"`

#### 2.6 — WalletViewModel
Create `ViewModels/WalletViewModel.swift`:
```swift
@Observable
class WalletViewModel {
    var walletManager = WalletManager()
    var solBalance: Double = 0
    var tokenBalances: [TokenBalance] = []
    var isLoading = false
    
    func setup() async {
        // Load or create wallet
        // Fetch initial balance
    }
    
    func refreshBalance() async {
        // Call SolanaClient.getBalance
    }
}
```

#### 2.7 — Wallet setup onboarding
Create `Views/WalletSetupView.swift`:
- "Create New Wallet" button
- Shows public key after creation
- "Get Free Devnet SOL" button (calls faucet)
- Transitions to chat after setup

#### 2.8 — Integration test: balance + faucet
- [ ] Create wallet → get public key
- [ ] Request airdrop from devnet faucet
- [ ] Query balance — should show > 0 SOL
- [ ] Display in UI

### Deliverables
- Wallet creation with Keychain persistence
- SOL balance queries from devnet
- Faucet airdrop working
- Wallet address displayed in UI

---

## Phase 3 — AI Tool Implementations ✅ COMPLETE

### Goals
- All 8 Foundation Models `Tool` conformances ✅
- AI calls tools and returns results ✅
- TransactionPreview with @Generable guided generation ✅
- Send SOL working end-to-end ✅

### Tasks

#### 3.1 — Tool protocol conformances

Each tool follows this pattern:
```swift
import FoundationModels

struct ToolName: Tool {
    let name = "toolName"
    let description = "What this tool does"

    struct Input: Codable {
        // Parameters the AI extracts from user prompt
    }

    func call(input: Input) async throws -> String {
        // Execute operation, return result string
    }
}
```

#### 3.2 — BalanceTool (`AI/Tools/BalanceTool.swift`)
- Input: `tokenMint: String?` (nil = SOL)
- Implementation: Call `SolanaClient.getBalance()` or `getTokenAccountsByOwner()`
- Output: formatted balance string with devnet label

#### 3.3 — FaucetTool (`AI/Tools/FaucetTool.swift`)
- Input: `amount: Double?` (default 1.0, cap at 2.0)
- Implementation: Call `SolanaClient.requestAirdrop()`
- Output: airdrop confirmation with tx signature

#### 3.4 — SendTool (`AI/Tools/SendTool.swift`)
- Input: `recipient: String`, `amount: Double`, `tokenMint: String?`
- Implementation:
  1. Validate recipient address (base58 check)
  2. Build transfer transaction
  3. Return TransactionPreview JSON for user confirmation
  4. On confirm: sign + send
- Output: tx signature or cancellation message

> **Key challenge:** Tool calling in Foundation Models is synchronous from the model's perspective. The tool `call()` must return a string. For user confirmation, the tool returns a preview string, and the AI asks the user to confirm. A follow-up message triggers the actual send.

#### 3.5 — PriceTool (`AI/Tools/PriceTool.swift`)
- Input: `tokenSymbol: String`
- Implementation: Call Jupiter Price API or CoinGecko
- Output: price in USD

#### 3.6 — SwapTool (`AI/Tools/SwapTool.swift`)
- Input: `fromToken: String`, `toToken: String`, `amount: Double`
- Implementation: Call Jupiter V6 quote API, return preview
- Output: swap quote with route, price impact, output amount

#### 3.7 — NFTTool (`AI/Tools/NFTTool.swift`)
- Input: none (uses connected wallet)
- Implementation: Call Helius DAS API `getAssetsByOwner`
- Output: list of NFT names + collection names

#### 3.8 — TransactionHistoryTool (`AI/Tools/TransactionHistoryTool.swift`)
- Input: `limit: Int?` (default 5)
- Implementation: Call `getSignaturesForAddress` + `getTransaction` RPC
- Output: recent tx summaries

#### 3.9 — OnRampTool (`AI/Tools/OnRampTool.swift`)
- Input: `amount: Double`, `currency: String?`
- Implementation: Return MoonPay sandbox URL to open
- Output: URL string for the user to open

#### 3.10 — TransactionPreview (Guided Generation)
Create `Models/TransactionPreview.swift`:
```swift
import FoundationModels

@Generable
struct TransactionPreview {
    @Guide(description: "The action: send, swap, stake")
    var action: String
    
    @Guide(description: "Amount in token units")
    var amount: Double
    
    @Guide(description: "Recipient address or .sol domain")
    var recipient: String
    
    @Guide(description: "Estimated network fee in SOL")
    var estimatedFee: Double
    
    @Guide(description: "One-sentence human-readable summary")
    var summary: String
}
```

Create `Views/TransactionPreviewCard.swift`:
- Card with action, amount, recipient, fee, summary
- "⚠️ DEVNET" prefix
- **Confirm** (green) and **Cancel** (red) buttons
- Confirmation calls back to ChatViewModel to execute

#### 3.11 — Wire tools into AI session
Update `ChatViewModel` to:
1. Create all tool instances (injecting `SolanaClient`, `WalletManager`)
2. Pass tools array to `AISession.initialize(tools:)`
3. Handle tool call results in message flow

#### 3.12 — End-to-end test flows
- [ ] "What's my balance?" → BalanceTool → shows SOL balance
- [ ] "Give me some SOL" → FaucetTool → airdrop + confirmation
- [ ] "Send 0.5 SOL to [address]" → SendTool → preview card → confirm → tx sent
- [ ] "What's the price of SOL?" → PriceTool → price response

### Deliverables
- All 8 tools implemented and callable by the AI
- Transaction preview cards with confirm/cancel
- Full send SOL flow working on devnet

---

## Phase 4 — DeFi & Sponsor Integrations ✅ COMPLETE (Phantom is P3 stretch)

### Goals
- Jupiter swap execution (quote + signed transaction) ✅
- Helius NFT data with images ✅ (NFTGalleryView with AsyncImage)
- MoonPay sandbox integration ✅ (OnRampTool opens sandbox URL in browser)
- Phantom wallet connection ❌ P3 stretch — cut for MVP

### Tasks

#### 4.1 — Jupiter swap execution
Create `Services/JupiterService.swift`:
```swift
class JupiterService {
    private let baseURL = URL(string: "https://api.jup.ag")!
    
    func getQuote(inputMint: String, outputMint: String, amount: UInt64) async throws -> SwapQuote
    func getSwapTransaction(quote: SwapQuote, userPublicKey: String) async throws -> Data
}
```
- GET `/quote` with params
- POST `/swap` to get serialized transaction
- User signs locally, sends via RPC

Well-known devnet token mints to hardcode:
| Token | Devnet Mint |
|---|---|
| SOL | `So11111111111111111111111111111111111111112` (wrapped) |
| USDC | Use devnet USDC mint from Jupiter |

#### 4.2 — Helius DAS integration
Create `Services/HeliusService.swift`:
```swift
class HeliusService {
    private let apiKey: String  // Devnet API key
    private let baseURL = URL(string: "https://devnet.helius-rpc.com")!
    
    func getAssetsByOwner(owner: String) async throws -> [NFTAsset]
    func getTokenMetadata(mints: [String]) async throws -> [TokenMetadata]
}
```
- DAS API: `getAssetsByOwner` for NFTs
- Token metadata for display names, symbols, logos

#### 4.3 — Price service
Create `Services/PriceService.swift`:
- Jupiter Price API: `GET https://api.jup.ag/price/v2?ids={mint}`
- Cache prices for 30 seconds
- Fallback to CoinGecko if Jupiter fails

#### 4.4 — MoonPay sandbox
Create integration for OnRampTool:
- Generate MoonPay widget URL with sandbox API key
- Parameters: `walletAddress`, `currencyCode=sol`, `baseCurrencyCode=usd`
- Open in system browser or in-app WKWebView
- Sandbox mode: test card `4242 4242 4242 4242`

#### 4.5 — Phantom connection (macOS)
Create `Wallet/PhantomConnector.swift`:
- **macOS approach:** Universal link / deeplink scheme (`phantom://`)
- Connect flow: `phantom://v1/connect?app_url=...&redirect_link=...`
- Handle callback URL with public key
- Sign transaction: `phantom://v1/signTransaction?transaction=...`
- Register URL scheme in Info.plist: `solmind://`

> **Complexity note:** Phantom browser extension integration via WKWebView is complex. For MVP, use deeplink-based connection which works on macOS with Phantom installed. Fall back to local wallet if Phantom not available.

#### 4.6 — Wallet switcher UI
Update `WalletSetupView.swift`:
- "Create New Wallet" → local Keychain wallet
- "Connect Phantom" → deeplink flow
- Show active wallet indicator in toolbar
- Switch between wallets

#### 4.7 — NFT gallery view
Create `Views/NFTGalleryView.swift`:
- Grid layout with `AsyncImage` for NFT artwork
- Collection name, NFT name
- Loads from Helius DAS data

#### 4.8 — Portfolio view
Create `Views/PortfolioView.swift`:
- SOL balance (prominent)
- SPL token list with balances + USD values
- "Get Devnet SOL" quick action button
- Pull-to-refresh

### Deliverables
- Token swaps working via Jupiter on devnet
- NFT display with images
- MoonPay sandbox accessible
- Phantom connection working on macOS
- Portfolio overview screen

---

## Phase 5 — Platform Polish & visionOS ⚠️ 80% COMPLETE

### Goals
- Polish macOS experience (primary demo platform) ✅ sidebar, shortcuts, dark mode
- iOS compact layout ✅ TabView, ⚠️ keyboard docking needs improvement
- iPadOS multi-column layout ✅ (inherits macOS NavigationSplitView via size class)
- visionOS spatial window + ornament ✅
- Error handling & edge cases ✅ network retry implemented (3× exponential backoff in SolanaClient.postRaw)
- Conversation persistence ✅ JSON files in Application Support
- Unit tests ⚠️ pending

### Tasks

#### 5.1 — macOS polish
- [ ] `NavigationSplitView` with conversation sidebar
- [ ] Toolbar: DevnetBadge + wallet indicator + new chat button
- [ ] Window title: "SolMind — Devnet"
- [ ] Keyboard shortcuts: `⌘N` new chat, `⌘Enter` send, `⌘K` clear
- [ ] Resizable panes with good defaults
- [ ] Dark mode support (test both appearances)
- [ ] Menu bar items (Help → About SolMind)

#### 5.2 — iOS adaptation
- [ ] Single-column `NavigationStack`
- [ ] Input field docks to keyboard
- [ ] Swipe actions on conversations (delete)
- [ ] Compact message bubbles
- [ ] Haptic feedback on transaction confirm (`UIImpactFeedbackGenerator`)
- [ ] Phantom deeplink connection: `phantom://v1/connect?...`

#### 5.3 — iPadOS adaptation
- [ ] `NavigationSplitView` with `columnVisibility` adaptive to size class
- [ ] Keyboard shortcut discoverability
- [ ] Stage Manager: proper window sizing
- [ ] Trackpad/mouse hover effects on buttons

#### 5.4 — visionOS adaptation
- [ ] Standard window for chat (works with no changes from macOS layout)
- [ ] **Ornament** for wallet balance summary (attached to window edge)
- [ ] Larger touch targets for spatial interaction
- [ ] Glass background material (`.glassBackgroundEffect()`)
- [ ] Test in visionOS Simulator

```swift
#if os(visionOS)
.ornament(attachmentAnchor: .scene(.leading)) {
    PortfolioSummaryView()
        .frame(width: 200)
        .glassBackgroundEffect()
}
#endif
```

#### 5.5 — Error handling
- [ ] Network unreachable → clear message + retry button
- [ ] Faucet rate limited → "Devnet faucet is rate-limited, try again in a minute"
- [ ] Foundation Models unavailable → "Enable Apple Intelligence in System Settings"
- [ ] Insufficient balance → AI explains and suggests faucet
- [ ] Invalid address → tool returns error, AI explains
- [ ] Transaction failed → show RPC error, link to explorer

#### 5.6 — Loading states
- [ ] Skeleton views while loading balance
- [ ] Typing indicator while AI processes
- [ ] Progress indicator for transaction confirmation
- [ ] Pull-to-refresh on portfolio

#### 5.7 — Persistence
- [ ] Save conversation history to disk (JSON files or SwiftData)
- [ ] Restore conversations on app launch
- [ ] Wallet keypair persists in Keychain across launches

### Deliverables
- Polished macOS experience ready for demo recording
- iOS, iPadOS, visionOS all functional
- Robust error handling
- Conversation persistence

---

## Phase 6 — Demo, Submission & QA 🔜 PENDING

### Goals
- Record submission video (3 min max)
- Write submission text
- Edge case testing
- Build distribution

### Tasks

#### 6.1 — Demo video script (macOS primary)
Recommended flow for 3-minute video:
1. **(0:00-0:15)** App opens, show Devnet badge, explain concept in voiceover
2. **(0:15-0:30)** "Give me some devnet SOL" → faucet airdrop
3. **(0:30-0:50)** "What's my balance?" → shows SOL balance
4. **(0:50-1:15)** "Send 1 SOL to [address]" → preview card → confirm → success
5. **(1:15-1:40)** "Swap 0.5 SOL to USDC" → Jupiter quote → confirm → success
6. **(1:40-2:00)** "Show my NFTs" → NFT gallery
7. **(2:00-2:20)** Show iPadOS multi-column layout + visionOS spatial window clips
8. **(2:20-2:45)** Explain privacy: all AI on-device, show no network calls for AI
9. **(2:45-3:00)** Closing: recap sponsors used (Phantom, Privy, MoonPay, Jupiter, Helius)

#### 6.2 — Screen recording
- [ ] macOS: use built-in screen recording or OBS
- [ ] iPadOS: QuickTime mirror recording
- [ ] visionOS: Simulator screenshot/recording
- [ ] Edit with iMovie or DaVinci Resolve (free)

#### 6.3 — Submission materials
- [ ] Update `README.md` with final screenshots
- [ ] Ensure `WHITEPAPER.md` matches implementation
- [ ] Write submission description for Colosseum platform
- [ ] List all sponsor integrations

#### 6.4 — Build distribution
- [ ] macOS: Archive → Export → Developer ID signed `.app` → zip
- [ ] Optionally: TestFlight build for iOS
- [ ] GitHub release with `.app.zip` attached

#### 6.5 — QA checklist
- [ ] Fresh install: wallet creation works
- [ ] All 8 AI tools return valid responses
- [ ] Faucet airdrop succeeds
- [ ] SOL transfer succeeds on devnet
- [ ] Swap via Jupiter succeeds on devnet
- [ ] NFT list loads from Helius
- [ ] Price queries return current data
- [ ] MoonPay sandbox opens correctly
- [ ] Conversation history persists across app restart
- [ ] Devnet badge is visible at all times
- [ ] App handles no internet gracefully
- [ ] App handles Foundation Models unavailable gracefully
- [ ] macOS, iOS, visionOS all build and run
- [ ] No crashes on standard flows

### Deliverables
- 3-minute demo video
- Distributable macOS `.app`
- Submission posted to Colosseum

---

## File-by-File Implementation Map

### Priority Order (build dependencies top-to-bottom)

| # | File | Phase | Depends On | Effort |
|---|---|---|---|---|
| 1 | `Config/SolanaConfig.swift` | 0 | — | Small |
| 2 | `Models/ChatMessage.swift` | 1 | — | Small |
| 3 | `Models/Conversation.swift` | 1 | ChatMessage | Small |
| 4 | `AI/AIInstructions.swift` | 1 | — | Small |
| 5 | `AI/AISession.swift` | 1 | AIInstructions | Medium |
| 6 | `Views/DevnetBadge.swift` | 1 | — | Small |
| 7 | `Views/MessageBubble.swift` | 1 | ChatMessage | Small |
| 8 | `Views/ChatView.swift` | 1 | MessageBubble, Conversation | Medium |
| 9 | `ViewModels/ChatViewModel.swift` | 1 | AISession, Conversation | Medium |
| 10 | `Solana/Models/RPCResponse.swift` | 2 | — | Small |
| 11 | `Solana/SolanaClient.swift` | 2 | RPCResponse, SolanaConfig | Large |
| 12 | `Solana/Keypair.swift` | 2 | — | Medium |
| 13 | `Wallet/LocalWallet.swift` | 2 | Keypair | Medium |
| 14 | `Wallet/WalletManager.swift` | 2 | LocalWallet | Medium |
| 15 | `ViewModels/WalletViewModel.swift` | 2 | WalletManager, SolanaClient | Medium |
| 16 | `Models/WalletState.swift` | 2 | — | Small |
| 17 | `Views/WalletSetupView.swift` | 2 | WalletViewModel | Medium |
| 18 | `Solana/TransactionBuilder.swift` | 2 | Keypair, SolanaClient | **Large** |
| 19 | `Solana/Models/TokenAccount.swift` | 2 | — | Small |
| 20 | `Solana/Models/TransactionModel.swift` | 2 | — | Small |
| 21 | `AI/Tools/BalanceTool.swift` | 3 | SolanaClient, WalletManager | Medium |
| 22 | `AI/Tools/FaucetTool.swift` | 3 | SolanaClient, WalletManager | Small |
| 23 | `AI/Tools/SendTool.swift` | 3 | TransactionBuilder, WalletManager | **Large** |
| 24 | `AI/Tools/PriceTool.swift` | 3 | PriceService | Small |
| 25 | `AI/Tools/SwapTool.swift` | 3 | JupiterService | Large |
| 26 | `AI/Tools/NFTTool.swift` | 3 | HeliusService | Medium |
| 27 | `AI/Tools/TransactionHistoryTool.swift` | 3 | SolanaClient | Medium |
| 28 | `AI/Tools/OnRampTool.swift` | 3 | — | Small |
| 29 | `Models/TransactionPreview.swift` | 3 | — | Small |
| 30 | `Views/TransactionPreviewCard.swift` | 3 | TransactionPreview | Medium |
| 31 | `Services/JupiterService.swift` | 4 | SolanaConfig | Large |
| 32 | `Services/HeliusService.swift` | 4 | SolanaConfig | Medium |
| 33 | `Services/PriceService.swift` | 4 | — | Small |
| 34 | `Wallet/PhantomConnector.swift` | 4 | WalletManager | Large |
| 35 | `Views/NFTGalleryView.swift` | 4 | HeliusService | Medium |
| 36 | `Views/PortfolioView.swift` | 4 | WalletViewModel | Medium |
| 37 | `Views/ConversationSidebar.swift` | 5 | Conversation | Medium |

**Total: 37 files to create/rewrite, ~3 large, ~14 medium, ~20 small**

---

## Dependency Graph

```
SolanaConfig
    ├── SolanaClient ──────────────── BalanceTool
    │       │                          FaucetTool
    │       │                          TransactionHistoryTool
    │       ├── TransactionBuilder ── SendTool
    │       │                          SwapTool (via Jupiter tx)
    │       └── Keypair ── LocalWallet ── WalletManager ── WalletViewModel
    │                                        │                  │
    │                                        │           WalletSetupView
    │                                        │
    │                                        ├── BalanceTool
    │                                        ├── FaucetTool
    │                                        └── SendTool
    │
    ├── JupiterService ── SwapTool
    ├── HeliusService ─── NFTTool, NFTGalleryView
    └── PriceService ──── PriceTool

AIInstructions ── AISession ── ChatViewModel ── ChatView ── ContentView
                                    │
ChatMessage ── Conversation ────────┘
                    │
         ConversationSidebar

TransactionPreview ── TransactionPreviewCard
```

---

## External Dependencies

### Third-Party Swift Packages — NONE for MVP

The entire app uses only Apple frameworks:
| Need | Apple Framework | Notes |
|---|---|---|
| AI / LLM | `FoundationModels` | On-device, macOS/iOS/visionOS 26 |
| Crypto (Ed25519) | `CryptoKit` (`Curve25519.Signing`) | Built-in |
| Keychain | `Security` framework | Built-in |
| HTTP networking | `URLSession` | Built-in |
| JSON encoding | `Foundation` (`JSONEncoder`/`JSONDecoder`) | Built-in |
| UI | `SwiftUI` | Built-in |
| visionOS spatial | `RealityKit` (optional volumetric) | Built-in |

> **Why no third-party packages:** Minimizes build complexity, avoids SPM resolution issues, reduces attack surface. Solana's wire format is simple enough to implement manually for the subset we need (transfers + token transfers). Jupiter and Helius are REST APIs — no SDK needed.

### APIs & Endpoints

| Service | Base URL | Auth | Mode |
|---|---|---|---|
| Solana RPC | `https://api.devnet.solana.com` | None | Devnet |
| Jupiter Quote | `https://api.jup.ag/quote/v6` | None | Devnet |
| Jupiter Swap | `https://api.jup.ag/swap/v6` | None | Devnet |
| Jupiter Price | `https://api.jup.ag/price/v2` | None | Public |
| Helius DAS | `https://devnet.helius-rpc.com/?api-key=XXX` | API key | Devnet |
| MoonPay Widget | `https://buy-sandbox.moonpay.com` | API key | Sandbox |
| Solana Explorer | `https://explorer.solana.com` | None | Public |

---

## API Keys & Configuration

Keys needed before starting Phase 4:

| Key | Where to get | Free tier? |
|---|---|---|
| Helius API key (devnet) | https://dev.helius.xyz | ✅ Free tier (100K credits/month) |
| MoonPay API key (sandbox) | https://dashboard.moonpay.com | ✅ Sandbox is free |

Keys NOT needed:
- Solana devnet RPC: public endpoint, no key required
- Jupiter API: no key required
- Phantom: no API key (deeplink protocol)
- Foundation Models: on-device, no key

Store keys in a `Config/Secrets.swift` file (gitignored):
```swift
enum Secrets {
    static let heliusAPIKey = "YOUR_HELIUS_DEVNET_KEY"
    static let moonpayAPIKey = "YOUR_MOONPAY_SANDBOX_KEY"
}
```

Add to `.gitignore`:
```
Config/Secrets.swift
```

Provide a `Config/Secrets.example.swift` with placeholder values.

---

## Testing Strategy

### Unit Tests (`SolMindTests/`)

| Test | What it validates |
|---|---|
| `Base58Tests` | Encode/decode roundtrip, known vectors |
| `KeypairTests` | Generation, signing, verification |
| `RPCResponseTests` | JSON decoding of RPC responses |
| `TransactionBuilderTests` | SOL transfer serialization matches expected bytes |
| `SolanaClientTests` | Mock RPC responses, balance parsing |
| `JupiterServiceTests` | Quote response parsing |

### Integration Tests (manual, on devnet)

| Test | Steps |
|---|---|
| Faucet → Balance | Airdrop 1 SOL → check balance shows 1 SOL |
| Send SOL | Have 2 SOL → send 0.5 → verify both balances |
| Swap | Have 1 SOL → swap to USDC → verify USDC balance |
| NFT list | Use wallet with known devnet NFTs |
| AI routing | "What's my balance?" → AI calls BalanceTool |
| AI multi-turn | Balance → Send → Confirm → Check new balance |

### UI Tests (`SolMindUITests/`)
- [ ] App launches without crash
- [ ] Chat input accepts text
- [ ] Send button triggers AI response
- [ ] Devnet badge is visible

---

## Risk Register

| # | Risk | Impact | Probability | Mitigation | Owner |
|---|---|---|---|---|---|
| R1 | Foundation Models API differs from WWDC docs | High | Medium | Test on day 1, adapt early. Check latest Xcode 26 release notes. | Dev |
| R2 | Tool calling doesn't work as expected | High | Medium | Fallback: parse AI text response to detect intent, call tools manually | Dev |
| R3 | Transaction serialization bugs | High | High | Start with simplest case (SOL transfer), test against known tx bytes, compare with explorer | Dev |
| R4 | Devnet faucet rate-limited / down | Medium | High | Implement retry with backoff; pre-fund a test wallet; cache last-known balance | Dev |
| R5 | Jupiter devnet has limited liquidity | Medium | Medium | Hardcode a few known devnet token pairs; show "limited liquidity on devnet" message | Dev |
| R6 | Phantom deeplink flow is flaky on macOS | Medium | High | Make local wallet the primary; Phantom is a "nice to have" | Dev |
| R7 | Context window (4K tokens) filled too fast | Medium | Medium | Trim old messages, keep only last 3 turns + system instructions | Dev |
| R8 | Guided generation (`@Generable`) doesn't produce reliable output | Medium | Medium | Fallback: use regular tool call that returns JSON string, parse manually | Dev |
| R9 | visionOS simulator doesn't support Foundation Models | Low | Medium | Test AI on macOS; visionOS demo focuses on UI/spatial, uses mock AI responses | Dev |
| R10 | Scope creep — trying to build everything | High | High | **Cut list:** Phantom, MoonPay, visionOS volumes are all STRETCH goals. Core = chat + balance + faucet + send + swap | Dev |

---

## Prioritized Cut List (if running out of time)

If time runs short, cut in this order (bottom = cut first):

| Priority | Feature | Impact of cutting |
|---|---|---|
| **P0 — Must have** | Chat UI + Foundation Models + BalanceTool + FaucetTool | App doesn't work without these |
| **P0 — Must have** | Local wallet (Keychain keypair) | No wallet = no blockchain ops |
| **P0 — Must have** | SendTool (SOL transfer) | Key demo moment |
| **P0 — Must have** | Devnet badge + configuration | Safety + judges need to see this |
| **P1 — Should have** | SwapTool (Jupiter) | Strong demo, sponsor integration |
| **P1 — Should have** | PriceTool | Quick win, enhances chat |
| **P1 — Should have** | TransactionPreviewCard | Safety requirement |
| **P1 — Should have** | macOS polish (sidebar, shortcuts) | Primary demo platform |
| **P2 — Nice to have** | NFTTool + NFTGalleryView (Helius) | Visual wow factor |
| **P2 — Nice to have** | TransactionHistoryTool | Useful but not demo-critical |
| **P2 — Nice to have** | iOS layout adaptation | Shows multiplatform |
| **P3 — Stretch** | Phantom deeplink connection | Complex integration |
| **P3 — Stretch** | MoonPay sandbox on-ramp | Sponsor bonus points |
| **P3 — Stretch** | visionOS ornaments + volumes | Visual wow for judges |
| **P3 — Stretch** | iPadOS-specific polish | Largely inherits macOS layout |
| **P3 — Stretch** | Conversation persistence (SwiftData) | Can demo without history |
| **P4 — Post-hackathon** | Privy SDK integration | Requires vendor SDK, complex auth flow |
| **P4 — Post-hackathon** | Multisig (Squads) | Deep integration, niche feature |
| **P4 — Post-hackathon** | watchOS companion | New target, limited value |

---

## Daily Milestones (5-week breakdown)

### Week 1: Foundation (Apr 6-12)
| Day | Milestone |
|---|---|
| Day 1 (Apr 6) | Phase 0 complete: clean project, folder structure, devnet config |
| Day 2 (Apr 7) | ChatMessage + Conversation models, AIInstructions |
| Day 3 (Apr 8) | AISession with Foundation Models, basic text response working |
| Day 4 (Apr 9) | ChatView + MessageBubble UI, messages display correctly |
| Day 5 (Apr 10) | ChatViewModel wired up, full chat loop working on macOS |
| Day 6 (Apr 11) | DevnetBadge, toolbar, ContentView with NavigationSplitView |
| Day 7 (Apr 12) | **Checkpoint:** Chat with AI works on macOS. No tools yet. |

### Week 2: Blockchain (Apr 13-19)
| Day | Milestone |
|---|---|
| Day 8 (Apr 13) | Base58 encoding, RPCResponse models |
| Day 9 (Apr 14) | SolanaClient: getBalance, requestAirdrop working |
| Day 10 (Apr 15) | Keypair generation + Keychain storage |
| Day 11 (Apr 16) | WalletManager + WalletViewModel + WalletSetupView |
| Day 12 (Apr 17) | BalanceTool + FaucetTool connected to AI |
| Day 13 (Apr 18) | TransactionBuilder for SOL transfers |
| Day 14 (Apr 19) | **Checkpoint:** "Give me SOL" → airdrop. "What's my balance?" → shows balance. |

### Week 3: Tools & DeFi (Apr 20-26)
| Day | Milestone |
|---|---|
| Day 15 (Apr 20) | SendTool end-to-end: build tx → sign → send → confirm |
| Day 16 (Apr 21) | TransactionPreview + TransactionPreviewCard UI |
| Day 17 (Apr 22) | PriceTool + PriceService |
| Day 18 (Apr 23) | JupiterService: quote API |
| Day 19 (Apr 24) | SwapTool: quote → preview → sign Jupiter tx → send |
| Day 20 (Apr 25) | HeliusService + NFTTool + NFTGalleryView |
| Day 21 (Apr 26) | **Checkpoint:** All P0 + P1 features working. Can demo balance/faucet/send/swap/price. |

### Week 4: Platform & Polish (Apr 27-May 3)
| Day | Milestone |
|---|---|
| Day 22 (Apr 27) | TransactionHistoryTool |
| Day 23 (Apr 28) | macOS polish: sidebar, keyboard shortcuts, dark mode |
| Day 24 (Apr 29) | iOS adaptation: compact layout, keyboard handling |
| Day 25 (Apr 30) | iPadOS adaptation: multi-column, Stage Manager |
| Day 26 (May 1) | visionOS: standard window + ornament for balance |
| Day 27 (May 2) | Error handling pass across all flows |
| Day 28 (May 3) | **Checkpoint:** macOS polished, iOS/iPadOS/visionOS functional. |

### Week 5: Ship (May 4-11)
| Day | Milestone |
|---|---|
| Day 29 (May 4) | Stretch: Phantom deeplinks, MoonPay sandbox |
| Day 30 (May 5) | Stretch: visionOS ornaments, conversation persistence |
| Day 31 (May 6) | QA: run full test matrix on all platforms |
| Day 32 (May 7) | Bug fixes from QA |
| Day 33 (May 8) | Record demo video (macOS primary) |
| Day 34 (May 9) | Edit video, write submission text |
| Day 35 (May 10) | Archive macOS .app, push to GitHub, submit |
| Buffer (May 11) | **Deadline day.** Final fixes only. Submit by EOD. |

---

## Quick Reference: Key Implementation Details

### Solana Transaction Wire Format (SOL Transfer)

```
Compact-array of signatures (1 × 64 bytes for single signer)
Message:
  Header:
    num_required_signatures: 1
    num_readonly_signed_accounts: 0
    num_readonly_unsigned_accounts: 1  (System Program)
  Compact-array of account addresses:
    [0] sender public key (32 bytes)
    [1] recipient public key (32 bytes) 
    [2] System Program ID: 11111111111111111111111111111111 (32 bytes)
  Recent blockhash (32 bytes)
  Compact-array of instructions:
    Instruction 0:
      program_id_index: 2 (System Program)
      compact-array of account indices: [0, 1]
      data: [2, 0, 0, 0] + little-endian u64 lamports (12 bytes total)
```

### Foundation Models Tool Protocol

```swift
protocol Tool {
    associatedtype Input: Codable
    var name: String { get }
    var description: String { get }
    func call(input: Input) async throws -> String
}
```

### Base58 Alphabet
```
123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
```

### Compact-u16 Encoding (Solana)
```
0-127:     1 byte  [value]
128-16383: 2 bytes [value & 0x7F | 0x80, value >> 7]
16384+:    3 bytes [value & 0x7F | 0x80, (value >> 7) & 0x7F | 0x80, value >> 14]
```

### System Program Transfer Instruction Data
```
[2, 0, 0, 0]              // instruction index 2 = Transfer (little-endian u32)
[lamports as u64 LE]      // 8 bytes, little-endian
```

---

*Last updated: April 6, 2026 — Day 1 of Colosseum Frontier Hackathon*
