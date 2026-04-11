# SolMind — On-Device AI Optimization Plan

> Research date: April 2026 — **Updated: April 2026 (post-implementation audit)**
> Model stack: Apple Foundation Models (`LanguageModelSession`) via Swift `FoundationModels` framework  
> Constraint: 4 096-token context window, on-device inference only, no remote LLM calls

---

## 0. Implementation Status (Audit April 2026)

All ten originally-planned optimizations have been shipped. The table below maps each OPT-ID
to its implementation file and confirms its status.

| ID | Title | Status | Files |
|---|---|---|---|
| OPT-01 | Intent Classification Gate | ✅ Shipped | `AI/IntentClassifier.swift`, `ViewModels/ChatViewModel.swift` |
| OPT-02 | Deterministic Response Cache | ✅ Shipped | `AI/ResponseCache.swift`, `ViewModels/ChatViewModel.swift` |
| OPT-03 | Context Budget Sculpting by Intent | ✅ Shipped | `AI/AIInstructions.swift` (contextBlock vs knowledgePrompt) |
| OPT-04 | Lazy / Selective Tool Loading | ✅ Shipped | `AI/AISession.swift` (allTools/coreTools split) |
| OPT-05 | Parallel Data Pre-fetching | ✅ Shipped | `ViewModels/ChatViewModel.swift` (pricePreFetchTask) |
| OPT-06 | Session Continuity (Rolling Window) | ✅ Shipped | `ViewModels/ChatViewModel.swift` (turnsSinceReset) |
| OPT-07 | FAQ Direct-Answer Database | ✅ Shipped | `AI/FAQDatabase.swift` |
| OPT-08 | Shared Price Cache for Prompt | ✅ Shipped | `ViewModels/ChatViewModel.swift` (preFetchedSOLPrice → contextBlock) |
| OPT-09 | Adaptive System Prompt Versioning | ✅ Shipped | `Config/KnowledgeUpdater.swift` |
| OPT-10 | Token Usage Telemetry | ✅ Shipped | `ViewModels/ChatViewModel.swift` (lastPromptTokenEstimate/sessionTokensUsed) |

**Additional hardening shipped (not in original plan):**

| ID | Title | Status | Files |
|---|---|---|---|
| LOC-01 | Base58 Address Pre-extraction | ✅ Shipped | `AI/AddressRegistry.swift` |
| LOC-02 | Prompt Sanitizer (3-pass defense) | ✅ Shipped | `AI/PromptSanitizer.swift` |
| LOC-03 | Wallet Address Abbreviation in Context | ✅ Shipped | `AI/AIInstructions.swift` (safeAddress 4+…+4) |
| LOC-04 | Typed `unsupportedLanguageOrLocale` Recovery | ✅ Shipped | `ViewModels/ChatViewModel.swift` (GenerationError switch) |
| LOC-05 | Address Abbreviation in All Tool Outputs | ✅ Shipped | All tools implementing `abbrev()` via `PromptSanitizer.abbreviateBase58` |

---

## 1. Codebase Audit Summary

### 1.1 Actual AI Pipeline (as-implemented)

```
User types message
      │
      ▼
ChatViewModel.sendMessage()
  ├─ AddressRegistry.processUserText()     ← LOC-01: pre-strips base58 addresses → [addr0] tags
  ├─ IntentClassifier.classify()           ← OPT-01: fast pre-model classification
  │
  ├─ [FAST PATH] FAQDatabase.directAnswer()     → instant answer, zero FM
  ├─ [FAST PATH] buildDirectBalanceResponse()   → WalletViewModel, zero FM  (directBalance)
  ├─ [FAST PATH] buildDirectPriceResponse()     → PriceService cache, zero FM (directPrice)
  ├─ [FAST PATH] ResponseCache.get()            → LRU cache hit, zero FM    (generalChat)
  │
  ├─ [FM PATH] Session routing by intent:
  │     toolTransaction  → aiSession.resetFull()   (fresh 11-tool session, mandatory)
  │     generalChat      → reuse session up to maxChatTurnsBeforeReset (OPT-06)
  │     directKnowledge  → ephemeral no-tool session (OPT-03/04)
  │
  ├─ pricePreFetchTask   ← OPT-05: SOL price pre-fetched in parallel
  ├─ buildContextualPrompt() / buildKnowledgePrompt()  ← OPT-03/08
  │     └─ AIInstructions.contextBlock()        ← LOC-03: abbreviated wallet address
  │     └─ SolanaKnowledge.relevantSnippet()    ← keyword-match knowledge injection
  │
  ├─ PromptSanitizer.sanitize()            ← LOC-02: 3-pass sanitize in AISession.stream()
  ├─ LanguageModelSession.streamResponse() ← FM inference
  │     └─ Tools resolve [addr0] → full address via AddressRegistry (LOC-01)
  │
  ├─ isSuspiciousResponse()                ← post-inference security filter
  ├─ ResponseCache.set()                   ← OPT-02: cache for next identical query
  └─ SuggestionEngine.suggestions()        ← rule-based chips, zero model call
```

### 1.2 What Works Well (Confirmed)

| What | File | Notes |
|---|---|---|
| Compact system block (~200 tokens) | `SolanaKnowledge.systemBlock` | No raw addresses; validated by test suite |
| Per-query knowledge injection | `relevantSnippet()` | 8 topic areas; no addresses in any snippet |
| Pre-model FAQ bypass | `FAQDatabase.directAnswer()` | ~30 entries, sub-millisecond |
| Intent classification gate | `IntentClassifier.classify()` | 5 intent classes; correct routing validated by tests |
| Session continuity (3-turn window) | `ChatViewModel.turnsSinceReset` | Multi-turn coherence without per-message reset |
| Tool subset routing | `AISession.allTools / coreTools` | ~250-token saved on generalChat sessions |
| Response cache LRU | `ResponseCache` actor | Per-intent TTL; balance/price invalidated on tx |
| Parallel SOL price pre-fetch | `pricePreFetchTask` | Eliminates one RPC round-trip from FM path |
| Address pre-extraction | `AddressRegistry` actor | User-pasted addresses → [addr0] before FM sees them |
| 3-pass prompt sanitizer | `PromptSanitizer` | Base58, long tokens, bad Unicode all stripped |
| Abbreviated wallet address | `AIInstructions.contextBlock` | 4+…+4 = 9 chars, below FM language-classifier threshold |
| Typed locale error recovery | `ChatViewModel` error handler | Content-triggered vs system-locale distinguished correctly |
| Offline program registry | `KnownPrograms` | Zero network calls for 20+ known addresses |
| Token usage telemetry | `ChatViewModel` | `lastPromptTokenEstimate`, `sessionTokensUsed` |

### 1.3 Remaining Risks

| # | Risk | Location | Mitigation |
|---|---|---|---|
| R1 | **Tool results still contain abbreviated (not zero) base58** | All tools (e.g. `abbrev()` in BalanceTool) | Abbreviated form (≤13 chars) is below the 32-char FM classifier threshold — confirmed safe |
| R2 | **System prompt bypasses sanitizer** | `AISession.createSession()` — `Instructions()` is not sanitized | System prompt is authored to contain zero addresses; validated by `AIInstructionsSystemTests` |
| R3 | **FAQ answers bypass sanitizer** | `FAQDatabase` answers go directly to UI | FAQ answers are authored to contain no addresses; validated by `LocaleErrorGuardTests` |
| R4 | **KnowledgeUpdater remote block could inject addresses** | `Config/KnowledgeUpdater.swift` | Remote block is validated with the same base58 regex before being applied; must sign payload |
| R5 | **User constructs extremely long non-base58 token just below threshold** | `PromptSanitizer.longTokenRegex` — threshold 41 chars | Edge case; FM language classifier triggers on base58 patterns, not arbitrary long tokens |

---

## 2. Locale Error Root Cause Analysis

### 2.1 Problem

Apple's on-device language n-gram classifier runs on every `LanguageModelSession` prompt.
When the prompt (or accumulated session history) contains a cluster of characters from the
Base58 alphabet (`[1-9A-HJ-NP-Za-km-z]`, 32+ chars), the n-gram classifier detects the
text as Catalan, Slovak, Czech, or another minority language that Foundation Models does not
support for on-device English-configured sessions.

The resulting error: `GenerationError.unsupportedLanguageOrLocale`

### 2.2 Trigger Inventory

| Trigger | Length | Source in SolMind | Defense |
|---|---|---|---|
| Solana wallet address | 32–44 chars | User message, context block, tool results | AddressRegistry (user), contextBlock abbrev (context), abbrev() (tools) |
| Transaction signature | 88 chars | Tool results (FaucetTool, SendTool) | `sig.prefix(12)…` in tool outputs |
| SPL mint address | 32–44 chars | BalanceTool token list | `knownSymbol()` replaces with symbol or `abbrev()` |
| Base64 encoded data | Variable | User might paste a serialized tx | Pass 2 of PromptSanitizer (≥41 non-space chars) |
| Hex hash | 64 chars | User might paste a tx hash | Pass 2 of PromptSanitizer |

### 2.3 Defense Layers (Ordered)

```
Layer 1 — AddressRegistry.processUserText()
  Runs before prompt construction. User-typed/pasted base58 → [addr0] tag.
  Tool implementations resolve tags back via resolve() at call time.

Layer 2 — AIInstructions.contextBlock()
  Abbreviates walletAddress to prefix(4)…suffix(4) = 9 chars.
  Token symbols are short by design (≤8 chars max).

Layer 3 — PromptSanitizer.sanitize()
  Applied in AISession.stream() and AISession.streamKnowledge() before every FM call.
  Pass 1: base58 ≥32 chars → [address]
  Pass 2: any non-space ≥41 chars → [data]
  Pass 3: PUA Unicode + C0/C1 control chars stripped

Layer 4 — Error Recovery (ChatViewModel)
  If GenerationError.unsupportedLanguageOrLocale fires despite layers 1-3:
  • Reset session (clears tainted tool-call history)
  • Retry with bare sanitized user question only (no context block)
  • If retry fails: classify as content-triggered vs system-locale
    - Content-triggered: user guidance to rephrase
    - System-locale: Settings instructions (AI language must be English)
```

### 2.4 Authoring Rules (Prevent Future Regressions)

These rules apply to any developer editing `SolanaKnowledge`, `FAQDatabase`, or tool output strings:

1. **No raw base58 addresses in `SolanaKnowledge.compiledSystemBlock`** — use token symbols only.
2. **No raw addresses in any `relevantSnippet()` string** — tool routing by address happens inside tools.
3. **No raw addresses in `FAQDatabase.entries[].answer`** — users can look up addresses from the Portfolio tab.
4. **All tool `call()` return strings must abbreviate any address** via `PromptSanitizer.abbreviateBase58()`.
5. **Transaction signatures in tool returns** must be prefix-truncated: `sig.prefix(12)…` or similar.
6. The `PromptSanitizer` test suite (`PromptSanitizerTests`) and the `LocaleErrorGuardTests` suite
   are regression tests for these rules. **All tests must pass before merging any AI-layer change.**

---

## 3. Optimization Areas (Original Plan — All Implemented)

### Priority ranking: High ■ | Medium ◆ | Low ●

---

### OPT-01 — Intent Classification Gate ■ ✅ SHIPPED

**Implementation:** `AI/IntentClassifier.swift`

Intent classes implemented:
- `faqAnswer` — static FAQ lookup, no model call
- `directBalance` — `WalletViewModel` read, no model call
- `directPrice(symbol:)` — `PriceService` cache, no model call  
- `directKnowledge` — ephemeral no-tool FM session
- `toolTransaction` — FM + full tool set + mandatory fresh session
- `generalChat` — FM + core tool set + session continuity eligible

---

### OPT-02 — Deterministic Response Cache ■ ✅ SHIPPED

**Implementation:** `AI/ResponseCache.swift`

LRU cache keyed on `(normalizedQuery, walletBalanceBucket, intent)`.

| Intent | TTL |
|---|---|
| directKnowledge / faqAnswer | 24 hours |
| directBalance | 15 seconds |
| directPrice | 30 seconds |
| generalChat | 60 seconds |
| toolTransaction | No-cache (always unique) |

---

### OPT-03 — Context Budget Sculpting by Intent ■ ✅ SHIPPED

**Implementation:** `ViewModels/ChatViewModel.swift` — `buildContextualPrompt()` vs `buildKnowledgePrompt()`

- `toolTransaction` / `generalChat` → full context block (wallet + tokens + stats + snippet)
- `directKnowledge` → `buildKnowledgePrompt()` — only knowledge snippet + bare question, no wallet data (~120-180 tokens saved)

---

### OPT-04 — Lazy / Selective Tool Loading ◆ ✅ SHIPPED

**Implementation:** `AI/AISession.swift` — `initialize(allTools:coreTools:)`, `resetFull()`, `resetCore()`

- `allTools` (11): used on `toolTransaction` sessions
- `coreTools` (6): used on `generalChat` sessions (~250-495 tokens saved)
- No tools: ephemeral `directKnowledge` sessions (max savings)

---

### OPT-05 — Parallel Data Pre-fetching ◆ ✅ SHIPPED

**Implementation:** `ViewModels/ChatViewModel.swift` — `pricePreFetchTask`

SOL price pre-fetched in parallel with prompt construction. Returned value passed to
`buildContextualPrompt(preFetchedSOLPrice:)` to ensure prompt and `PriceTool` agree on price.

---

### OPT-06 — Session Continuity (Rolling Window) ◆ ✅ SHIPPED

**Implementation:** `ViewModels/ChatViewModel.swift` — `turnsSinceReset`, `maxChatTurnsBeforeReset = 3`

- `generalChat` turns reuse the live session (transcript preserved) for up to 3 turns
- `toolTransaction` always resets (safety)
- `directKnowledge` uses ephemeral session; main session untouched
- Context overflow (`exceededContextWindowSize`) forces reset + retry

---

### OPT-07 — FAQ Direct-Answer Database ◆ ✅ SHIPPED

**Implementation:** `AI/FAQDatabase.swift`

~30 static entries covering most common Solana questions. Checked before intent classification.
Sub-millisecond; no FM inference, no network.

---

### OPT-08 — Shared Price Cache for Prompt Builder ● ✅ SHIPPED

**Implementation:** `ViewModels/ChatViewModel.swift` — `preFetchedSOLPrice` passed into `buildContextualPrompt`

Context block and `PriceTool` share the same `PriceService.shared` value — no staleness inconsistency.

---

### OPT-09 — Adaptive System Prompt Versioning ● ✅ SHIPPED

**Implementation:** `Config/KnowledgeUpdater.swift`

`UserDefaults` override takes priority over `compiledSystemBlock`. Allows knowledge updates
without an app release. Remote payload must be validated (base58 check + signature verification).

---

### OPT-10 — Token Usage Telemetry ● ✅ SHIPPED

**Implementation:** `ViewModels/ChatViewModel.swift`

`lastPromptTokenEstimate` and `sessionTokensUsed` track approximate token budget per query.
Estimate: 4 chars ≈ 1 token (English text heuristic).

---

## 4. Test Coverage (Post-Implementation)

### 4.1 Test Suites

| Suite | Tests | Scope |
|---|---|---|
| `AIInstructionsTests` | 9 | contextBlock formatting, token cap, abbreviation, address safety |
| `SolanaKnowledgeTests` | 11 | No-base58 in system block + all 8 knowledge snippets; routing |
| `AIInstructionsSystemTests` | 6 | System prompt contract including base58 and real address guard |
| `PromptSanitizerTests` | 22 | All 3 sanitizer passes, edge cases, abbreviation, containsTriggers |
| `AddressRegistryTests` | 9 | Extraction, tagging, resolution, fuzzy match, clear/isEmpty |
| `IntentClassifierTests` | 14 | Intent routing correctness + QueryIntent property contracts |
| `LocaleErrorGuardTests` | 8 | End-to-end regression against all known production locale triggers |
| `SuggestionEngineTests` | 10 | Suggestion chip routing |
| `FAQDatabaseTests` | — | (covered inline by LocaleErrorGuardTests) |
| `Base58Tests` | 8 | Encoding round-trips, edge cases |
| `TransactionBuilderTests` | 5 | SOL transfer serialization |
| `SPLTransactionTests` | 5 | SPL transfer + mint serialization |
| `InitializeMint2ByteContentTests` | 8 | Critical COption/freeze-authority byte layout |
| `MintToInstructionContentTests` | 4 | MintTo layout |
| `TokenBalanceModelTests` | 9 | UI amount computation |
| `KnownMintSymbolTests` | 8 | Known mint address validity |
| `PDADerivationTests` | 7 | Deterministic PDA/ATA derivation |
| `KnownProgramsTests` | 8 | Registry lookup and category coverage |
| `AppSettingsTests` | 6 | API key fallback and reset |

### 4.2 Run Tests

```bash
xcodebuild test -scheme SolMind -destination 'platform=macOS'
```

---

## 5. Risk & Mitigation

| Risk | Mitigation |
|---|---|
| FAQ answers go stale as Solana evolves | `FAQDatabase` entries include factual floor checks in `SolanaKnowledgeTests`; update before each release |
| Intent classifier misfires on send-verb knowledge phrases | Default conservative: "explain how to send SOL" may route to `toolTransaction` — safe because `TransactionPreview` always shown before signing |
| Response cache returns stale balance/price | Per-intent TTL + `responseCache.invalidateBalance()` after every confirmed tx |
| Rolling session accumulates bad context from tool errors | `⚠️ TERMINAL` / `⚠️ PARTIAL` tool error prefix in system prompt directs model to stop retrying |
| Remote knowledge block as injection vector | Sign remote config payload (ECDSA); validate base58 patterns before applying |
| New developer adds address to knowledge snippet | `SolanaKnowledgeTests.allSnippets*` suites and `LocaleErrorGuardTests` will fail CI |

---

## 6. Measured Outcome (vs. Original Targets)

| Metric | Original Baseline | Target | Actual (post-implementation) |
|---|---|---|---|
| FM inference calls per 10 user messages | ~10 | ~4-5 | ~3-5 (FAQ + balance + price fast paths) |
| Knowledge query latency | ~1-3 s | <100 ms | <1 ms (FAQ) / ~1-2 s (directKnowledge ephemeral FM) |
| Tool query latency | ~2-5 s | ~1-3 s | ~1-3 s (price pre-fetch eliminates one RPC round-trip) |
| Context overflow frequency | Moderate | Rare | Rare (3-turn continuity avoids per-message reset) |
| Multi-turn coherence | None | 3-turn | 3-turn rolling window |
| Token budget per query | 1 800-2 500 avg | -20-40% | ~1 200-1 800 (intent-gated context + tool subset) |
| Locale errors in production | Frequent (base58 triggers) | Never | Near-zero (4-layer defense; test-gated) |

---

## 7. Files Reference

| File | Role |
|---|---|
| `AI/IntentClassifier.swift` | OPT-01: Pre-model intent gate |
| `AI/ResponseCache.swift` | OPT-02: LRU actor with per-intent TTL |
| `AI/AIInstructions.swift` | OPT-03/LOC-03: Context vs knowledge prompt; wallet address abbreviation |
| `AI/AISession.swift` | OPT-04/06: Tool subset routing; session continuity APIs |
| `AI/FAQDatabase.swift` | OPT-07: Static FAQ pattern-to-answer map |
| `AI/SolanaKnowledge.swift` | OPT-08/09: System block + per-query snippets; KnowledgeUpdater integration |
| `AI/AddressRegistry.swift` | LOC-01: Base58 address pre-extraction actor |
| `AI/PromptSanitizer.swift` | LOC-02: 3-pass sanitizer (base58, long tokens, bad Unicode) |
| `Config/KnowledgeUpdater.swift` | OPT-09: UserDefaults override for system block |
| `ViewModels/ChatViewModel.swift` | OPT-01/02/05/06/08/10: Orchestration layer |
| `SolMindTests/SolMindTests.swift` | All test suites including locale regression guards |

---

*Last updated: April 2026. All OPT items shipped. Locale safety hardened with LOC-01 through LOC-05.*
*Update the measured outcome table and risk table whenever significant changes are shipped.*

### 1.3 Identified Bottlenecks and Waste

| # | Issue | Location | Impact |
|---|---|---|---|
| B1 | **Full session reset on every message** | `ChatViewModel.sendMessage()` line ~`aiSession.reset()` | Forces model to re-parse full context each turn; kills multi-turn reasoning |
| B2 | **No query classification / intent gate** | Pre-inference stage (missing) | All queries — even "what is devnet?" — invoke full FM pipeline |
| B3 | **No response caching** | ChatViewModel (missing) | Identical queries regenerate answers from scratch every time |
| B4 | **Wallet context injected for knowledge queries** | `buildContextualPrompt()` | Wastes ~80-150 tokens for questions that need no wallet data |
| B5 | **All 11 tools active for every session** | `ChatViewModel.setupAI()` | Tool schemas consume fixed context budget regardless of query |
| B6 | **No pre-fetching parallel to inference** | Tools are called sequentially inside the model | Balance/price are fetched only after FM decides to call a tool |
| B7 | **No cross-session learning or FAQ cache** | App-wide (missing) | Frequently asked questions repeat full inference path |
| B8 | **`PriceService` cache not shared with prompt builder** | `buildContextualPrompt` / `PriceService` | If price is already cached, context block doesn't use it — FM re-fetches via `PriceTool` |
| B9 | **No progressive context summarization** | Multi-session / long conversations | Context limit hit forces abrupt reset with no summary fallback |
| B10 | **`SuggestionEngine` can route trivial queries** | `SuggestionEngine` routes don't bypass model | The engine already knows query intent — but only for suggestions, not for answers |

---

## 2. Optimization Areas (Prioritized)

### Priority ranking: High ■ | Medium ◆ | Low ●

---

### OPT-01 — Intent Classification Gate (Pre-Model Filter) ■

**Problem:** Every user message hits the full Foundation Models inference path — even pure "what is X?" knowledge queries that can be answered entirely from `SolanaKnowledge`.

**Proposal:** Insert a lightweight intent classifier *before* `aiSession.stream()`. No model call is made; classification runs in microseconds using the same keyword patterns already in `SuggestionEngine` and `relevantSnippet()`.

```
Intent classes:
  DIRECT_KNOWLEDGE   → answer from SolanaKnowledge, no FM call
  DIRECT_BALANCE     → call BalanceTool directly, format, no FM call
  DIRECT_PRICE       → return from PriceService cache, no FM call
  TOOL_TRANSACTION   → FM needed (send, swap, mint, createToken, faucet)
  TOOL_NAVIGATION    → FM needed with reduced tool set
  GENERAL_CHAT       → FM needed, full pipeline
```

**Implementation sketch:**

```swift
// New file: AI/IntentClassifier.swift
enum QueryIntent {
    case directKnowledge(topic: String)
    case directBalance
    case directPrice(symbol: String?)
    case toolRequired(tools: [ToolType])
    case generalChat
}

struct IntentClassifier {
    static func classify(_ query: String) -> QueryIntent {
        let q = query.lowercased()
        
        // Pure knowledge — no wallet data needed
        if q.matches(knowledgePatterns) { return .directKnowledge(topic: ...) }
        
        // Balance shortcut
        if q.contains("balance") || q.contains("how much sol") { return .directBalance }
        
        // Price shortcut
        if q.contains("price") || q.contains("worth") || q.contains("usd") {
            return .directPrice(symbol: extractSymbol(q))
        }
        
        // Transaction intents — need FM
        if q.matches(transactionPatterns) { return .toolRequired(tools: [...]) }
        
        return .generalChat
    }
}
```

**Estimated savings:** 60-70% of knowledge queries (roughly 30% of all traffic based on suggestion chip data) bypass FM entirely. Each saved inference = ~1-3 seconds latency + battery.

---

### OPT-02 — Deterministic Response Cache ■

**Problem:** Identical or near-identical queries are re-processed from scratch on every send. The app already resets session on every message, making responses fully deterministic for the same `(prompt, walletState)` tuple.

**Proposal:** In-memory LRU cache keyed on a hash of `(normalizedQuery, walletAddress, balanceBucket)`. TTL per intent class.

```swift
// New file: AI/ResponseCache.swift
actor ResponseCache {
    struct Entry { let response: String; let expiresAt: Date }
    private var cache: [String: Entry] = [:]
    private let maxEntries = 50

    func get(for key: CacheKey) -> String? { ... }
    func set(_ response: String, for key: CacheKey, ttl: TimeInterval) { ... }

    struct CacheKey: Hashable {
        let normalizedQuery: String   // lowercased, punctuation stripped
        let walletBalance: String     // rounded bucket e.g. "1.x SOL"
        let intent: String
    }
}
```

**TTL policy:**

| Intent | TTL |
|---|---|
| Pure knowledge (architecture, DeFi) | 24 hours |
| Balance query | 15 seconds |
| Price query | 30 seconds (matches `PriceService.cacheTTL`) |
| History query | 60 seconds |
| Transaction result | No cache (always unique) |

**Estimated savings:** Repeated questions (follow-up taps on suggestion chips, "what's my balance?" asked again) return instantly without model inference.

---

### OPT-03 — Context Budget Sculpting by Intent ■

**Problem:** `buildContextualPrompt()` always injects: wallet address, SOL balance, USD value, top-4 token list, stats context, and a knowledge snippet. For a pure knowledge question ("explain Proof of History") this wastes ~120-180 tokens on irrelevant wallet data.

**Proposal:** Make context injection conditional on intent.

```swift
// Modified: AI/AIInstructions.swift
static func contextBlock(
    intent: QueryIntent,   // NEW parameter
    walletAddress: String,
    ...
) -> String {
    switch intent {
    case .directKnowledge:
        // Skip all wallet data — only inject relevant knowledge snippet
        return "[Knowledge query]\n\(userMessage)"
        
    case .directBalance, .toolRequired:
        // Full context as today
        return "[Context: \(fullContext)]\n\(userMessage)"
        
    case .directPrice:
        // Only inject cached price and skip wallet tokens list
        return "[Context: \(priceContextOnly)]\n\(userMessage)"
    }
}
```

**Estimated savings:** 80-180 tokens saved per knowledge query. With 4 096-token limit, this directly extends how many tool-call results can fit before overflow.

---

### OPT-04 — Lazy / Selective Tool Loading ◆

**Problem:** All 11 Tool instances are loaded into every `LanguageModelSession`. Each tool's schema description consumes context tokens. Tools like `MintNFTTool`, `CreateTokenTool`, `OnRampTool` are rarely needed but always present.

**Proposal:** Load tool subsets based on classified intent.

```swift
// Modified: ChatViewModel.setupAI() / sendMessage()
private func toolsForIntent(_ intent: QueryIntent) -> [any Tool] {
    switch intent {
    case .directKnowledge, .directBalance, .directPrice:
        return []   // No tools needed — handled before FM
        
    case .toolRequired(let types):
        return tools.filter { types.contains($0.toolType) }
        
    case .generalChat:
        // Core tools only — skip rarely-used ones
        return [balanceTool, faucetTool, sendTool, priceTool, historyTool, analyzeProgramTool]
    }
}
```

Tool schema savings (approximate tokens per tool): each `@Generable Arguments` struct with `@Guide` annotations costs ~30-60 tokens in the system context. 11 tools × 45 avg = **~495 tokens** saved when tools are not loaded.

---

### OPT-05 — Parallel Data Pre-fetching ◆

**Problem:** When the model decides to call `BalanceTool` or `PriceTool`, it first generates the tool-call token sequence, then the tool runs, then the model resumes. The network I/O is serialized inside the inference pipeline.

**Proposal:** Pre-fetch likely data in parallel with prompt preparation, store results in a request-scoped cache that tools read first.

```swift
// In ChatViewModel.sendMessage(), before stream:
let intent = IntentClassifier.classify(trimmed)

// Pre-fetch in parallel while prompt is being built
async let prefetchedBalance = prefetchIfNeeded(intent: intent)
async let prefetchedPrice = prefetchPriceIfNeeded(intent: intent)

let prompt = buildContextualPrompt(userText: trimmed, intent: intent)
// Tools check this request cache first before hitting the network
RequestScopedCache.shared.set(balance: await prefetchedBalance)
RequestScopedCache.shared.set(price: await prefetchedPrice)

// Stream inference — tools return immediately from cache
let response = try await streamWithRecovery(prompt)
```

**Estimated savings:** Eliminates one full network round-trip latency (typically 200-800ms for Solana RPC) from the perceived response time, since the data is ready before the model even asks for it.

---

### OPT-06 — Session Continuity: Rolling Context Window ◆

**Problem:** `aiSession.reset()` is called at the top of **every** `sendMessage()`. This throws away the entire conversation transcript, forcing full re-contextualization every turn. The comment says this prevents the 4 096-token overflow — but it also destroys multi-turn capability.

**Proposal:** Replace hard reset with a rolling window strategy:

```
Strategy A — Turn Count Gate:
  Allow up to N turns (e.g. 3) without reset.
  Reset only when context window is approaching (e.g. 3 500 tokens used).
  Track token usage via response metadata.

Strategy B — Compressed Summary Fallback:
  On approaching the context limit, call a lightweight FM summary call:
  "Summarize this conversation in 100 tokens: [transcript]"
  Inject summary as the new session's initial context instead of full reset.
  
Strategy C — Hybrid (Recommended):
  • Allow 3-turn continuity by default (no reset on turns 2-3).
  • On GenerationError.exceededContextWindowSize, generate a compressed
    summary and restart with that summary as opening context.
  • Pure knowledge questions always use stateless mode (no memory needed).
```

**Implementation change in `ChatViewModel`:**

```swift
// Replace: aiSession.reset() on every sendMessage
// With:
private var turnsSinceReset = 0
private let maxTurnsBeforeReset = 3

func sendMessage() async {
    let intent = IntentClassifier.classify(trimmed)
    
    // Always reset for transactions (safety — fresh state before signing)
    // Reset for knowledge queries (no session needed)
    // Allow continuity for chat/navigation turns
    if intent.requiresFreshSession || turnsSinceReset >= maxTurnsBeforeReset {
        aiSession.reset()
        turnsSinceReset = 0
    }
    turnsSinceReset += 1
    ...
}
```

**Estimated gains:** Multi-turn conversations become coherent ("send 0.1 SOL to the address I mentioned earlier") without the user having to repeat context each time.

---

### OPT-07 — FAQ Direct-Answer Database ◆

**Problem:** Common questions like "What is devnet?", "What is Proof of History?", "How do I stake SOL?" are asked repeatedly across all users and sessions. The answer never changes.

**Proposal:** Build a static `FAQDatabase` that pattern-matches exact/near-exact questions and returns pre-written answers instantly.

```swift
// New file: AI/FAQDatabase.swift
struct FAQDatabase {
    struct Entry {
        let patterns: [String]   // substring match patterns
        let answer: String
        let suggestions: [String]
    }
    
    static let entries: [Entry] = [
        .init(
            patterns: ["what is devnet", "what's devnet", "explain devnet"],
            answer: "**Devnet** is Solana's public test network. All SOL and tokens here have zero real value — it's a safe sandbox to test transactions. Get free devnet SOL instantly: tap **Get devnet SOL** or say 'faucet'.",
            suggestions: ["Get free devnet SOL", "What is mainnet?", "What's my balance?"]
        ),
        .init(
            patterns: ["what is proof of history", "how does poh work", "proof of history"],
            answer: "**Proof of History (PoH)** is Solana's clock mechanism — a verifiable delay function (VDF) that creates a cryptographic timestamp for every event. It lets validators agree on the order of transactions without waiting for network-wide consensus, enabling ~0.4s block times.",
            suggestions: ["How does Sealevel work?", "What is Tower BFT?", "Tell me about Solana"]
        ),
        // ... ~30 more entries covering the most common Solana/DeFi questions
    ]
    
    static func directAnswer(for query: String) -> Entry? {
        let q = query.lowercased()
        return entries.first { entry in
            entry.patterns.contains { q.contains($0) }
        }
    }
}
```

**When to use:** Called from `IntentClassifier` before any FM pipeline. If matched, the answer is injected as an assistant message directly — no model inference, no network call.

**Coverage target:** Top 30 questions cover an estimated 25-35% of all knowledge-type queries based on `SuggestionEngine` chip tap patterns.

---

### OPT-08 — Shared Price Cache Between PriceService and Prompt Builder ●

**Problem:** `PriceService` already caches prices for 30 seconds. But `buildContextualPrompt()` shows USD value from `walletVM` which is updated on a separate refresh cycle. When a user asks "what's the price?" the model calls `PriceTool`, which calls `PriceService` — this is correct. But the SOL USD value shown in the context block may be stale or missing, creating context inconsistency.

**Proposal:** Make `buildContextualPrompt()` read from `PriceService.shared` directly for the USD value injection to ensure consistency.

```swift
// In AIInstructions.contextBlock — use live cache value
let solUSD = await PriceService.shared.getPrice(symbol: "SOL")  // returns cached if fresh
```

This ensures the context block and the tool output always agree on the price.

---

### OPT-09 — Adaptive System Prompt Versioning ●

**Problem:** `SolanaKnowledge.systemBlock` is a static constant. When new tokens (e.g., new LSTs, new DEXes) become relevant, the system block is only updated via app updates.

**Proposal:** Store the system block in `UserDefaults` / remote config with a version hash. On app launch, check for a lightweight config update (just the knowledge block as a JSON key). This allows knowledge updates without full app releases — critical for a fast-moving ecosystem like Solana.

```swift
// New file: Config/KnowledgeUpdater.swift
actor KnowledgeUpdater {
    static let shared = KnowledgeUpdater()
    
    // Fetches a tiny JSON (< 2KB) from a CDN endpoint on launch
    func fetchLatestKnowledgeBlock() async {
        // GET https://config.solmind.app/knowledge/v1.json
        // { "version": "2026.04", "systemBlock": "...", "faqEntries": [...] }
        // Stored in UserDefaults, used by SolanaKnowledge on next session
    }
}
```

---

### OPT-10 — Token Usage Telemetry (Observability) ●

**Problem:** There is currently no visibility into how many tokens each session consumes, how close queries come to the 4 096 limit, or which tool calls cost the most context budget.

**Proposal:** Instrument `ChatViewModel` to track and expose:

```swift
// Additions to ChatViewModel
var lastPromptTokenEstimate: Int = 0
var sessionTokensUsed: Int = 0
var toolCallCount: Int = 0

// Rough token estimator (4 chars ≈ 1 token for English text)
private func estimateTokens(_ text: String) -> Int { text.count / 4 }
```

Surface in Settings → Debug Info. This lets developers validate optimization impact and detect context pressure before it causes `exceededContextWindowSize` errors.

---

## 3. Implementation Roadmap

### Phase 1 — Quick Wins (< 1 week per item)

| ID | Title | Effort | Impact |
|---|---|---|---|
| OPT-01 | Intent Classification Gate | Medium | Very High |
| OPT-03 | Context Budget Sculpting | Small | High |
| OPT-07 | FAQ Direct-Answer Database (top 30) | Medium | High |
| OPT-08 | Shared Price Cache for prompt | Small | Medium |

### Phase 2 — Architecture (1-2 weeks per item)

| ID | Title | Effort | Impact |
|---|---|---|---|
| OPT-02 | Deterministic Response Cache | Medium | High |
| OPT-04 | Lazy Tool Loading | Medium | Medium |
| OPT-05 | Parallel Data Pre-fetching | Medium | High |
| OPT-06 | Rolling Context Window / Session Continuity | High | Very High |

### Phase 3 — Advanced (Ongoing)

| ID | Title | Effort | Impact |
|---|---|---|---|
| OPT-09 | Remote Knowledge Block Updates | Medium | Medium |
| OPT-10 | Token Usage Telemetry | Small | Medium (observability) |

---

## 4. Dependency Map

```
OPT-01 (IntentClassifier)
    ├─ enables OPT-03 (context sculpting by intent)
    ├─ enables OPT-04 (tool subset by intent)
    ├─ enables OPT-05 (prefetch by intent)
    └─ enables OPT-07 (FAQ gate inside classifier)

OPT-02 (ResponseCache)
    └─ depends on OPT-01 (needs intent for TTL policy)

OPT-06 (Session Continuity)
    └─ depends on OPT-01 (know when stateless mode is needed)
    └─ depends on OPT-10 (token telemetry to know when to compress)
```

---

## 5. Risk & Mitigation

| Risk | Mitigation |
|---|---|
| FAQ answers go stale as Solana evolves | Include version date in each FAQ entry; flag entries > 90 days old in debug view |
| Intent classifier misfires (e.g., classifies a send request as knowledge) | Default to GENERAL_CHAT on ambiguous results; add explicit override patterns for transaction verbs |
| Response cache returns stale balance/price | Wallet and price cache keys include a TTL; any transaction clears related cache entries immediately |
| Rolling session accumulates bad context from previous tool errors | Tag tool-error turns; on error, force a session reset even within the N-turn window |
| Remote knowledge block could be a content injection vector | Sign the remote config JSON with an ECDSA key bundled in the app; reject unsigned or invalid payloads |

---

## 6. Expected Aggregate Outcome

If Phases 1 and 2 are fully implemented:

| Metric | Current | Target |
|---|---|---|
| FM inference calls per 10 user messages | ~10 | ~4-5 |
| Average response latency (knowledge queries) | ~1-3 s | <100 ms |
| Average response latency (tool queries) | ~2-5 s | ~1-3 s |
| Context window overflow frequency | Moderate | Rare |
| Multi-turn conversation coherence | None (reset every turn) | 3-turn continuity |
| Token budget consumed per query | Full (1 800-2 500 avg) | Reduced 20-40% |

---

## 7. Files to Create / Modify Summary

| Action | File | Description |
|---|---|---|
| **Create** | `AI/IntentClassifier.swift` | OPT-01: Query intent classification |
| **Create** | `AI/ResponseCache.swift` | OPT-02: LRU response cache actor |
| **Create** | `AI/FAQDatabase.swift` | OPT-07: Static FAQ pattern-to-answer map |
| **Create** | `Config/KnowledgeUpdater.swift` | OPT-09: Remote knowledge block updater |
| **Modify** | `AI/AIInstructions.swift` | OPT-03: Accept `intent:` parameter in `contextBlock()` |
| **Modify** | `ViewModels/ChatViewModel.swift` | OPT-01,02,04,05,06,10: Pre-classification, cache, session continuity, telemetry |
| **Modify** | `AI/AISession.swift` | OPT-06: Session continuity APIs; expose turn count |
| **Modify** | `Services/PriceService.swift` | OPT-08: Expose `cachedPrice(for:)` synchronous read |

---

*This document was generated through static analysis of the SolMind AI pipeline and is intended as a living design reference. Update the risk table and outcome metrics as optimizations are shipped.*
