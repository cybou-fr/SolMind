import Foundation
import FoundationModels

// MARK: - Chat ViewModel

@Observable
@MainActor
class ChatViewModel {
    var conversations: [Conversation] = []
    var activeConversation: Conversation?
    var inputText: String = ""
    var isProcessing = false
    var aiUnavailable = false
    var aiUnavailableReason: String = "Apple Intelligence unavailable. Enable it in System Settings."

    // Suggestions shown after each AI response
    var currentSuggestions: [String] = []

    // AI stats
    var lastResponseTime: TimeInterval?

    // Session metrics (reset on newConversation)
    var sessionMessageCount: Int = 0
    var sessionTransactionCount: Int = 0

    // Transient banners
    var showContextResetBanner: Bool = false
    var showSuccessAnimation: Bool = false

    private let aiSession = AISession()
    private let solanaClient = SolanaClient()
    private let store = ConversationStore()
    private var confirmationHandlerRef: TransactionConfirmationHandler?

    // Weak-ish references injected by setupAI — safe since all @MainActor same lifetime
    private var walletVM: WalletViewModel?
    private var statsVM: SolanaStatsViewModel?

    // Context injection flag — reset per conversation
    private var hasInjectedContext = false

    // OPT-02: Response cache — LRU with per-intent TTL
    private let responseCache = ResponseCache()

    // OPT-06: Session continuity — number of consecutive generalChat turns on the current session.
    // Resets to 0 whenever the session is recreated (transaction, overflow, conversation switch).
    private var turnsSinceReset: Int = 0
    private let maxChatTurnsBeforeReset: Int = 3

    // OPT-10: Token usage telemetry (4 chars ≈ 1 token for English text).
    var lastPromptTokenEstimate: Int = 0
    var sessionTokensUsed: Int = 0

    init() {
        let initial = Conversation(title: "New Chat")
        conversations.append(initial)
        activeConversation = initial
        loadPersistedConversations()
    }

    // MARK: - Persistence

    func loadPersistedConversations() {
        let loaded = (try? store.loadAll()) ?? []
        if !loaded.isEmpty {
            conversations = loaded
            activeConversation = conversations.first
        }
    }

    private func persistActive() {
        guard let convo = activeConversation else { return }
        try? store.save(convo)
    }

    // MARK: - AI Setup

    func setupAI(
        walletManager: WalletManager,
        confirmationHandler: TransactionConfirmationHandler,
        walletViewModel: WalletViewModel? = nil,
        statsViewModel: SolanaStatsViewModel? = nil
    ) {
        self.walletVM = walletViewModel
        self.statsVM = statsViewModel
        self.confirmationHandlerRef = confirmationHandler

        let jupiterService = JupiterService()
        let heliusService = HeliusService()

        // OPT-04: Core tools (6) — used for general-chat queries (no transaction intent).
        // Omits heavy transaction tools that consume context without benefit for chat turns.
        let coreTools: [any Tool] = [
            BalanceTool(walletManager: walletManager, solanaClient: solanaClient),
            FaucetTool(walletManager: walletManager, solanaClient: solanaClient),
            SendTool(walletManager: walletManager, solanaClient: solanaClient, confirmationHandler: confirmationHandler),
            PriceTool(),
            TransactionHistoryTool(walletManager: walletManager, solanaClient: solanaClient),
            AnalyzeProgramTool(solanaClient: solanaClient)
        ]

        // Transaction-only tools added on top for toolTransaction intent sessions.
        let txOnlyTools: [any Tool] = [
            SwapTool(walletManager: walletManager, jupiterService: jupiterService, solanaClient: solanaClient, confirmationHandler: confirmationHandler),
            NFTTool(walletManager: walletManager, heliusService: heliusService),
            MintNFTTool(walletManager: walletManager, heliusService: heliusService, confirmationHandler: confirmationHandler),
            CreateTokenTool(walletManager: walletManager, solanaClient: solanaClient, confirmationHandler: confirmationHandler),
            OnRampTool(walletManager: walletManager)
        ]

        let allTools = coreTools + txOnlyTools
        aiSession.initialize(allTools: allTools, coreTools: coreTools)

        // Proactive availability check — surfaces language/device issues immediately on launch.
        if let reason = aiSession.checkAvailability() {
            aiUnavailableReason = reason
            aiUnavailable = true
        }
    }

    // MARK: - Manual Message Insertion

    /// Append a synthetic assistant message (e.g. result of a form-driven mint).
    func addSystemMessage(_ content: String) {
        let msg = ChatMessage(role: .assistant, content: content, timestamp: Date())
        activeConversation?.messages.append(msg)
        persistActive()
    }

    // MARK: - Send Message

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        // Pre-extract any raw base58 addresses from the user's message and store them
        // in AddressRegistry. The FM prompt will use [addr0] / [addr1] tags — no raw
        // base58 in the prompt means no Croatian/Catalan language-classifier triggers.
        // Tools (SendTool) resolve the tags back to full addresses at call time.
        let promptText = await AddressRegistry.shared.processUserText(trimmed)
        let hadAddresses = await !AddressRegistry.shared.isEmpty

        // OPT-01: Classify intent before any FM or tool work.
        let intent = IntentClassifier.classify(trimmed)
        let walletBalance = walletVM?.solBalance ?? 0

        // OPT-05: Pre-warm price cache concurrently while we set up the session.
        // PriceService returns cached value immediately if fresh; otherwise the HTTP
        // request starts in parallel and will be ready by the time FM calls PriceTool.
        let pricePreFetchTask = Task { try? await PriceService.shared.getPrice(symbol: "SOL") }

        let userMessage = ChatMessage(role: .user, content: trimmed, timestamp: Date())
        activeConversation?.messages.append(userMessage)
        inputText = ""
        isProcessing = true
        currentSuggestions = []
        sessionMessageCount += 1
        confirmationHandlerRef?.clearPending()
        confirmationHandlerRef?.resetLockout()

        let assistantMsg = ChatMessage(role: .assistant, content: "", timestamp: Date(), isStreaming: true)
        activeConversation?.messages.append(assistantMsg)
        let msgIndex = (activeConversation?.messages.count ?? 1) - 1

        // ── FAST PATH 1: FAQ direct answer (OPT-07) ─────────────────────────────
        // Checked before intent routing — FAQs bypass even the intent classifier.
        if let faqEntry = FAQDatabase.directAnswer(for: trimmed) {
            finishDirectResponse(
                faqEntry.answer,
                suggestions: faqEntry.suggestions,
                at: msgIndex, query: trimmed,
                intent: .faqAnswer, walletBalance: walletBalance
            )
            return
        }

        // ── FAST PATH 2: Direct balance (OPT-05 — no FM needed) ─────────────────
        if case .directBalance = intent {
            let response = buildDirectBalanceResponse()
            finishDirectResponse(response, at: msgIndex, query: trimmed,
                                 intent: intent, walletBalance: walletBalance)
            return
        }

        // ── FAST PATH 3: Direct price (OPT-05 — no FM needed) ───────────────────
        if case .directPrice(let sym) = intent {
            let response = await buildDirectPriceResponse(symbol: sym ?? "SOL")
            finishDirectResponse(response, at: msgIndex, query: trimmed,
                                 intent: intent, walletBalance: walletBalance)
            return
        }

        // ── RESPONSE CACHE CHECK (OPT-02) ────────────────────────────────────────
        let cacheKey = ResponseCache.makeKey(query: trimmed, intent: intent, walletBalance: walletBalance)
        if let cached = await responseCache.get(key: cacheKey) {
            updateMessage(at: msgIndex, content: cached, isStreaming: false)
            currentSuggestions = SuggestionEngine.suggestions(
                for: cached, userMessage: trimmed, walletHasBalance: walletBalance > 0
            )
            autoTitleIfNeeded(from: trimmed)
            isProcessing = false
            persistActive()
            return
        }

        // ── FM INFERENCE PATH ────────────────────────────────────────────────────
        // OPT-06 + OPT-04: Session continuity gate + lazy tool selection.
        // Transactions always get a fresh full-tool session (safety-critical).
        // generalChat reuses the session for up to maxChatTurnsBeforeReset turns.
        // directKnowledge uses an ephemeral no-tool session — main session untouched.
        switch intent {
        case .directKnowledge:
            break   // ephemeral knowledge session; main session and turnsSinceReset unchanged
        case .toolTransaction:
            hasInjectedContext = false
            aiSession.resetFull()
            turnsSinceReset = 0
        default:  // generalChat
            if turnsSinceReset >= maxChatTurnsBeforeReset {
                hasInjectedContext = false
                aiSession.resetCore()
                turnsSinceReset = 0
            }
            // If within the turn window: reuse the live session — transcript is preserved.
            turnsSinceReset += 1
        }

        // OPT-08: Resolve the fresh SOL price from the pre-fetch task (OPT-05).
        // Falls back to walletVM's cached USD value if price fetch is unavailable.
        let preFetchedSOLPrice: Double? = await pricePreFetchTask.value

        do {
            let start = Date()
            let fullResponse: String

            if case .directKnowledge = intent {
                // OPT-03: Ephemeral no-tool session — saves all tool schema tokens
                let prompt = buildKnowledgePrompt(userText: promptText)
                // OPT-10: Token estimation
                lastPromptTokenEstimate = prompt.count / 4
                sessionTokensUsed += lastPromptTokenEstimate
                fullResponse = try await collectKnowledgeStream(prompt, msgIndex: msgIndex)
            } else {
                // OPT-08: Pass pre-fetched price to buildContextualPrompt so the
                // context block always shows a consistent USD value even if walletVM
                // hasn't refreshed yet.
                // Use promptText (addresses already replaced with [addr0] tags) so that
                // raw base58 never reaches the FM language classifier.
                let prompt = buildContextualPrompt(userText: promptText, preFetchedSOLPrice: preFetchedSOLPrice)
                // OPT-10: Token estimation
                lastPromptTokenEstimate = prompt.count / 4
                sessionTokensUsed += lastPromptTokenEstimate
                fullResponse = try await streamWithRecovery(prompt)
            }

            lastResponseTime = Date().timeIntervalSince(start)

            let finalContent = isSuspiciousResponse(fullResponse)
                ? """
                  ⚠️ Security Warning: The AI generated a response that appeared to request sensitive information (private key or seed phrase). This response has been blocked.

                  SolMind will NEVER ask for your private key. If you see such a request, it is a scam attempt. Your wallet is managed securely on-device.
                  """
                : fullResponse
            updateMessage(at: msgIndex, content: finalContent, isStreaming: false)

            autoTitleIfNeeded(from: trimmed)

            currentSuggestions = SuggestionEngine.suggestions(
                for: fullResponse, userMessage: trimmed, walletHasBalance: walletBalance > 0
            )

            scheduleBalanceRefreshIfNeeded(for: fullResponse)

            // OPT-02: Cache FM response (TTL 0 = no-cache for transactions)
            let ttl = ResponseCache.ttl(for: intent)
            if ttl > 0 {
                await responseCache.set(finalContent, for: cacheKey, ttl: ttl)
            }

        } catch AIError.contextWindowExceeded {
            aiSession.resetFull()
            hasInjectedContext = false
            turnsSinceReset = 0   // OPT-06: overflow kills continuity window
            showContextResetBannerBriefly()
            Task {
                try? await Task.sleep(for: .seconds(4))
                await walletVM?.refreshBalance()
            }
            let retryPrompt = buildContextualPrompt(userText: promptText, preFetchedSOLPrice: preFetchedSOLPrice)
            do {
                let start = Date()
                let retryResponse = try await collectStream(retryPrompt)
                lastResponseTime = Date().timeIntervalSince(start)
                let retryContent = isSuspiciousResponse(retryResponse)
                    ? "⚠️ Security Warning: The AI generated a response that appeared to request sensitive information. This response has been blocked."
                    : retryResponse
                updateMessage(at: msgIndex, content: retryContent, isStreaming: false)
                autoTitleIfNeeded(from: trimmed)
                currentSuggestions = SuggestionEngine.suggestions(
                    for: retryResponse, userMessage: trimmed, walletHasBalance: walletBalance > 0
                )
            } catch {
                updateMessage(at: msgIndex,
                              content: "⚠️ The conversation context window was exceeded and could not be recovered. Please start a new chat (⌘K) and repeat your request.",
                              isStreaming: false)
                confirmationHandlerRef?.clearPending()
            }
            isProcessing = false
            persistActive()
            aiSession.resetFull()
            return
        } catch let genError as LanguageModelSession.GenerationError {
            confirmationHandlerRef?.clearPending()
            switch genError {
            case .unsupportedLanguageOrLocale:
                // Strategy: this error has two causes:
                //   (A) Content-triggered — tool results in session history contained base58
                //       addresses / long encoded tokens that FM's language classifier flagged.
                //       Recoverable: reset session (clears tainted history) + bare prompt.
                //   (B) System locale — Apple Intelligence language ≠ English. Not recoverable
                //       by changing the prompt; requires a Settings change.
                //
                // Recovery: 1. reset session (clears all history from prior tool calls)
                //           2. retry with the BARE sanitized user question — no context injection.
                //              A bare prompt excludes wallet data, stats, and knowledge snippets
                //              that might marginally trigger the classifier.
                //           3. If bare retry also fails → case B → show Settings guidance.
                aiSession.resetFull()
                hasInjectedContext = false
                turnsSinceReset = 0

                let (sanitizedInput, inputHadTriggers) = PromptSanitizer.sanitize(promptText)

                // Bare retry — user question only, no context block, clean session.
                do {
                    let bareResponse = try await streamWithRecovery(sanitizedInput)
                    updateMessage(at: msgIndex, content: bareResponse, isStreaming: false)
                    currentSuggestions = SuggestionEngine.suggestions(
                        for: bareResponse, userMessage: trimmed, walletHasBalance: walletBalance > 0
                    )
                    autoTitleIfNeeded(from: trimmed)
                    let retryCacheKey = ResponseCache.makeKey(query: trimmed, intent: intent, walletBalance: walletBalance)
                    let retryTTL = ResponseCache.ttl(for: intent)
                    if retryTTL > 0 {
                        await responseCache.set(bareResponse, for: retryCacheKey, ttl: retryTTL)
                    }
                } catch AIError.contextWindowExceeded {
                    // Bare retry hit context overflow — show overflow message, NOT content-trigger message.
                    aiSession.resetFull()
                    updateMessage(at: msgIndex,
                                  content: "⚠️ The context window was exceeded even on recovery. Please start a new chat (⌘K) and repeat your request.",
                                  isStreaming: false)
                } catch {
                    // Bare retry failed with locale or other error.
                    // Use hadAddresses (pre-extracted) + sanitizer check to classify the error.
                    let hadTriggers = inputHadTriggers || hadAddresses || PromptSanitizer.containsTriggers(trimmed)
                    if hadTriggers {
                        // Content-triggered: user typed/pasted a raw address or encoded blob.
                        updateMessage(at: msgIndex, content: """
                            ⚠️ Your message contained data (like a wallet address or encoded text) \
                            that Apple Intelligence's language filter couldn't handle.

                            **Try:** Rephrase in plain English — for example, "send SOL to my \
                            friend's wallet" instead of pasting an address directly. Use the QR \
                            scanner to send to a specific address.
                            """, isStreaming: false)
                        // Session was already reset; AI is still functional.
                    } else {
                        // System locale mismatch — prompt was clean but FM still rejected it.
                        updateMessage(at: msgIndex, content: """
                            ⚠️ Apple Intelligence Language Error

                            The on-device model returned a language filter error. This usually \
                            means the Apple Intelligence language doesn't match your app language.

                            **To fix:**
                            1. **System Settings → Apple Intelligence & Siri → Language** → English (US)
                            2. **System Settings → General → Language & Region → Apps → SolMind** → English
                            3. Restart the app after changing.
                            """, isStreaming: false)
                        aiUnavailableReason = "Apple Intelligence language mismatch. See System Settings → Apple Intelligence & Siri."
                        aiUnavailable = true
                    }
                }
            default:
                updateMessage(at: msgIndex, content: "⚠️ AI error: \(genError.localizedDescription)", isStreaming: false)
            }
        } catch {
            let errorDesc = error.localizedDescription
            let errorLower = errorDesc.lowercased()
            confirmationHandlerRef?.clearPending()
            updateMessage(at: msgIndex, content: errorDesc, isStreaming: false)
            if errorLower.contains("not available") || errorLower.contains("not initialized") {
                aiUnavailableReason = "Apple Intelligence unavailable. Enable it in System Settings."
                aiUnavailable = true
            }
        }

        isProcessing = false
        persistActive()

        // OPT-06: Session continuity — only wipe the session after transactions.
        // For generalChat the session survives to the next turn (up to maxChatTurnsBeforeReset).
        // For directKnowledge the ephemeral session was already discarded; main session is clean.
        if case .toolTransaction = intent {
            aiSession.resetFull()
        }
    }

    // MARK: - Conversation Management

    func newConversation() {
        let convo = Conversation()
        conversations.insert(convo, at: 0)
        activeConversation = convo
        aiSession.resetFull()
        hasInjectedContext = false
        turnsSinceReset = 0
        currentSuggestions = []
        lastResponseTime = nil
        sessionMessageCount = 0
        sessionTransactionCount = 0
        lastPromptTokenEstimate = 0
        sessionTokensUsed = 0
        Task { await responseCache.invalidateAll() }
        Task { await AddressRegistry.shared.clear() }
    }

    func deleteConversation(_ convo: Conversation) {
        let id = convo.id
        conversations.removeAll { $0.id == id }
        if activeConversation?.id == id {
            activeConversation = conversations.first
        }
        try? store.delete(id)
    }

    // MARK: - Context Injection

    /// Prepends wallet + network context to the FIRST message of each session.
    /// Subsequent messages are sent as-is (context already in the live session transcript).
    /// - Parameter preFetchedSOLPrice: OPT-08 — fresh price from PriceService pre-fetch task.
    ///   Used as fallback when walletVM.solUSDValue is nil, ensuring context block and
    ///   PriceTool always agree on the current SOL price.
    private func buildContextualPrompt(userText: String, preFetchedSOLPrice: Double? = nil) -> String {
        guard !hasInjectedContext,
              let wvm = walletVM,
              wvm.isWalletReady else { return userText }

        hasInjectedContext = true

        // OPT-08: Prefer walletVM cached USD value; fall back to pre-fetched price.
        let effectiveSOLUSD = wvm.solUSDValue ?? preFetchedSOLPrice

        let tokenSummary = wvm.tokenBalances.map {
            (symbol: $0.symbol, uiAmount: $0.uiAmount, usdValue: $0.usdValue)
        }
        return AIInstructions.contextBlock(
            walletAddress: wvm.publicKey ?? "unknown",
            solBalance: wvm.solBalance,
            solUSDValue: effectiveSOLUSD,
            tokenBalances: tokenSummary,
            statsContext: statsVM?.contextSummary ?? "",
            userMessage: userText
        )
    }

    // MARK: - Knowledge Prompt (OPT-03)
    // Minimal prompt for directKnowledge intent: no wallet data, no tool schemas.
    // Token footprint: system block (~200) + knowledge snippet (~100-200) + question.

    private func buildKnowledgePrompt(userText: String) -> String {
        if let snippet = SolanaKnowledge.relevantSnippet(for: userText) {
            return "[Knowledge: \(snippet)]\n\n\(userText)"
        }
        return userText
    }

    // MARK: - Direct Response Helpers (OPT-05)

    /// Format wallet balance from WalletViewModel — bypasses FM entirely.
    private func buildDirectBalanceResponse() -> String {
        guard let wvm = walletVM, wvm.isWalletReady else {
            return "Wallet is not connected yet. Please wait a moment and try again."
        }
        guard wvm.solBalance > 0 else {
            return """
            ⚠️ DEVNET: Your wallet is empty (0 SOL).

            Say **"Get devnet SOL"** to receive a free airdrop instantly — no fees, no sign-up required.
            """
        }
        var response = "✅ DEVNET: **Wallet Balance**\n"
        let solStr = String(format: "%.6f SOL", wvm.solBalance)
        if let usd = wvm.solUSDValue {
            response += String(format: "• **SOL:** %@ ($%.2f USD)\n", solStr, usd)
        } else {
            response += "• **SOL:** \(solStr)\n"
        }
        if !wvm.tokenBalances.isEmpty {
            response += "\n**SPL Tokens:**\n"
            for token in wvm.tokenBalances.prefix(6) {
                let amount = token.uiAmount >= 1_000
                    ? String(format: "%.0f", token.uiAmount)
                    : String(format: "%.4f", token.uiAmount)
                if let usd = token.usdValue, usd > 0 {
                    response += String(format: "• **%@:** %@ ($%.2f USD)\n", token.symbol, amount, usd)
                } else {
                    response += "• **\(token.symbol):** \(amount)\n"
                }
            }
        }
        return response
    }

    /// Fetch current token price from PriceService cache — bypasses FM entirely.
    private func buildDirectPriceResponse(symbol: String) async -> String {
        let sym = symbol.uppercased()
        do {
            if let price = try await PriceService.shared.getPrice(symbol: sym) {
                return String(format: "✅ DEVNET: Current price of **%@**: $%.4f USD", sym, price)
            }
            return "⚠️ Could not fetch price for \(sym). The price API may be temporarily unavailable — try again in a moment."
        } catch {
            return "⚠️ Price lookup failed: \(error.localizedDescription)"
        }
    }

    /// Finalize a non-FM (direct) response: update UI, cache, and complete turn.
    private func finishDirectResponse(
        _ response: String,
        suggestions: [String]? = nil,
        at msgIndex: Int,
        query: String,
        intent: QueryIntent,
        walletBalance: Double
    ) {
        updateMessage(at: msgIndex, content: response, isStreaming: false)
        if let explicit = suggestions {
            currentSuggestions = explicit
        } else {
            currentSuggestions = SuggestionEngine.suggestions(
                for: response, userMessage: query, walletHasBalance: walletBalance > 0
            )
        }
        autoTitleIfNeeded(from: query)
        let key = ResponseCache.makeKey(query: query, intent: intent, walletBalance: walletBalance)
        let ttl = ResponseCache.ttl(for: intent)
        if ttl > 0 {
            Task { await responseCache.set(response, for: key, ttl: ttl) }
        }
        isProcessing = false
        persistActive()
    }

    /// Collect streamed chunks from the knowledge-only ephemeral session.
    private func collectKnowledgeStream(_ prompt: String, msgIndex: Int) async throws -> String {
        var result = ""
        for try await chunk in aiSession.streamKnowledge(prompt) {
            result = chunk
            if let count = activeConversation?.messages.count, count > 0 {
                activeConversation?.messages[count - 1].content = result
            }
        }
        return result
    }

    /// Auto-title the conversation from the first user message (first 40 chars).
    private func autoTitleIfNeeded(from text: String) {
        if activeConversation?.messages.count == 2,
           let title = activeConversation?.messages.first?.content {
            activeConversation?.title = String(title.prefix(40))
        }
    }

    // MARK: - Safe message mutation

    /// Bounds-checked write to a streaming assistant message.
    /// Guards against the conversation being deleted while the AI is generating.
    private func updateMessage(at index: Int, content: String, isStreaming: Bool) {
        guard let convo = activeConversation, index < convo.messages.count else { return }
        activeConversation?.messages[index].content = content
        activeConversation?.messages[index].isStreaming = isStreaming
    }

    // MARK: - Streaming with context-window recovery

    /// Runs `collectStream` and converts context-window errors into `AIError.contextWindowExceeded`
    /// so `sendMessage` can retry with a clean session.
    ///
    /// Uses **typed** `LanguageModelSession.GenerationError` matching rather than string matching.
    /// String matching was fragile: the "generationerror" wildcard accidentally caught
    /// `.unsupportedLanguageOrLocale` (treating it as recoverable overflow), and broke
    /// whenever Apple changed error descriptions or localised them.
    private func streamWithRecovery(_ prompt: String) async throws -> String {
        do {
            return try await collectStream(prompt)
        } catch let genError as LanguageModelSession.GenerationError {
            switch genError {
            case .exceededContextWindowSize:
                aiSession.resetFull()
                throw AIError.contextWindowExceeded
            case .unsupportedLanguageOrLocale:
                throw genError  // hard stop — not recoverable by resetting context
            default:
                if isContextWindowError(genError) {
                    aiSession.resetFull()
                    throw AIError.contextWindowExceeded
                }
                throw genError
            }
        } catch {
            if isContextWindowError(error) {
                aiSession.resetFull()
                throw AIError.contextWindowExceeded
            }
            throw error
        }
    }

    /// Returns `true` only for errors that represent a context-window overflow.
    ///
    /// Design notes:
    /// - Prefer typed enum matching over string matching for `LanguageModelSession.GenerationError`.
    /// - Do NOT match bare "exceeded" — it also matches Solana RPC "Rate limit exceeded",
    ///   which would wrongly reset the AI session on a network error.
    /// - The old "generationerror" string wildcard was removed: it matched ALL
    ///   `GenerationError` subtypes including `.unsupportedLanguageOrLocale`, causing
    ///   locale errors to be silently swallowed and retried as overflow recoveries.
    private func isContextWindowError(_ error: Error) -> Bool {
        if case AIError.contextWindowExceeded = error { return true }
        if let genError = error as? LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = genError { return true }
            if case .unsupportedLanguageOrLocale = genError { return false }
        }
        let text = error.localizedDescription.lowercased()
        return text.contains("4096")
            || text.contains("context length")
            || text.contains("context window")
            || text.contains("singleextend")
            || text.contains("inferencefailed")
    }

    private func collectStream(_ prompt: String) async throws -> String {
        var result = ""
        for try await chunk in aiSession.stream(prompt) {
            result = chunk
            // Update streaming content in real-time (bounds-checked)
            if let count = activeConversation?.messages.count, count > 0 {
                activeConversation?.messages[count - 1].content = result
            }
        }
        return result
    }

    // MARK: - Auto Balance Refresh

    /// Schedule a balance refresh after a tool that changes wallet balance completes.
    /// Uses a delay to allow the Solana network to confirm the transaction.
    private func scheduleBalanceRefreshIfNeeded(for response: String) {
        guard let walletVM else { return }
        let lower = response.lowercased()

        // Airdrop — longer delay since faucet transactions are slower
        let isAirdrop = lower.contains("airdrop") && lower.contains("sol")
        // Any state-changing tool that reports devnet success (✅ or ⚠️ prefix)
        let isTransfer = lower.contains("✅ devnet")
            || lower.contains("devnet: token created")
            || lower.contains("devnet: nft minted")
            || lower.contains("devnet: transaction sent")
            || lower.contains("devnet: token transfer sent")
            || lower.contains("devnet: swap executed")

        guard isAirdrop || isTransfer else { return }

        sessionTransactionCount += 1
        triggerSuccessAnimation()

        let delay: Duration = isAirdrop ? .seconds(6) : .seconds(3)
        Task {
            try? await Task.sleep(for: delay)
            await walletVM.refreshBalance()
            // OPT-02: Invalidate stale balance cache entries after confirmed balance change
            await responseCache.invalidateBalance()
        }
    }

    private func triggerSuccessAnimation() {
        showSuccessAnimation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSuccessAnimation = false
        }
    }

    private func showContextResetBannerBriefly() {
        showContextResetBanner = true
        ToastManager.shared.info("Conversation context refreshed to free up memory.")
        Task {
            try? await Task.sleep(for: .seconds(4))
            showContextResetBanner = false
        }
    }

    // MARK: - Security

    // Detect responses where the AI is actively soliciting credentials.
    // Purely informational mentions ("your key is stored securely on-device") are NOT blocked.
    private func isSuspiciousResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        // Solicitation verbs that indicate the AI is requesting something from the user
        let requestVerbs = ["enter your", "provide your", "send me your", "share your",
                            "tell me your", "type your", "paste your", "give me your",
                            "submit your", "input your"]
        // Credential nouns
        let credentialNouns = ["private key", "seed phrase", "mnemonic", "secret key",
                               "recovery phrase", "wallet secret", "secret phrase"]
        // Block only if a request verb appears near a credential noun
        for verb in requestVerbs {
            if lower.contains(verb) {
                for noun in credentialNouns {
                    if lower.contains(noun) { return true }
                }
            }
        }
        return false
    }
}
