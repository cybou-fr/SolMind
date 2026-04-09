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
        let tools: [any Tool] = [
            BalanceTool(walletManager: walletManager, solanaClient: solanaClient),
            FaucetTool(walletManager: walletManager, solanaClient: solanaClient),
            SendTool(walletManager: walletManager, solanaClient: solanaClient, confirmationHandler: confirmationHandler),
            PriceTool(),
            SwapTool(walletManager: walletManager, jupiterService: jupiterService, solanaClient: solanaClient, confirmationHandler: confirmationHandler),
            NFTTool(walletManager: walletManager, heliusService: heliusService),
            MintNFTTool(walletManager: walletManager, heliusService: heliusService, confirmationHandler: confirmationHandler),
            CreateTokenTool(walletManager: walletManager, solanaClient: solanaClient, confirmationHandler: confirmationHandler),
            TransactionHistoryTool(walletManager: walletManager, solanaClient: solanaClient),
            OnRampTool(walletManager: walletManager),
            AnalyzeProgramTool(solanaClient: solanaClient)
        ]
        aiSession.initialize(tools: tools)
    }

    // MARK: - Send Message

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        // Stateless: fresh session + full context injection on every message.
        // Prevents context accumulation across turns (4096-token limit).
        aiSession.reset()
        hasInjectedContext = false

        let userMessage = ChatMessage(role: .user, content: trimmed, timestamp: Date())
        activeConversation?.messages.append(userMessage)
        inputText = ""
        isProcessing = true
        currentSuggestions = []
        sessionMessageCount += 1
        // Reset confirmation lockout so the first tool call in this message can always show a card.
        confirmationHandlerRef?.resetLockout()

        let assistantMsg = ChatMessage(role: .assistant, content: "", timestamp: Date(), isStreaming: true)
        activeConversation?.messages.append(assistantMsg)
        let msgIndex = (activeConversation?.messages.count ?? 1) - 1

        do {
            // Build contextual prompt (always injects wallet/network context — stateless mode)
            let prompt = buildContextualPrompt(userText: trimmed)

            let start = Date()
            let fullResponse = try await streamWithRecovery(prompt)
            lastResponseTime = Date().timeIntervalSince(start)

            let finalContent = isSuspiciousResponse(fullResponse)
                ? """
                  ⚠️ Security Warning: The AI generated a response that appeared to request sensitive information (private key or seed phrase). This response has been blocked.

                  SolMind will NEVER ask for your private key. If you see such a request, it is a scam attempt. Your wallet is managed securely on-device.
                  """
                : fullResponse
            updateMessage(at: msgIndex, content: finalContent, isStreaming: false)

            // Auto-title conversation from first user message
            if activeConversation?.messages.count == 2,
               let title = activeConversation?.messages.first?.content {
                activeConversation?.title = String(title.prefix(40))
            }

            // Generate contextual follow-up suggestions
            currentSuggestions = SuggestionEngine.suggestions(
                for: fullResponse,
                userMessage: trimmed,
                walletHasBalance: (walletVM?.solBalance ?? 0) > 0
            )

            // Auto-refresh balance after balance-changing tool executions
            scheduleBalanceRefreshIfNeeded(for: fullResponse)

        } catch AIError.contextWindowExceeded {
            // Session was already reset at the top of sendMessage; reset again after overflow just in case.
            aiSession.reset()
            hasInjectedContext = false
            showContextResetBannerBriefly()
            // Tools may have executed successfully before overflow — refresh balance to pick up any changes.
            Task {
                try? await Task.sleep(for: .seconds(4))
                await walletVM?.refreshBalance()
            }
            let retryPrompt = buildContextualPrompt(userText: trimmed)
            do {
                let start = Date()
                let retryResponse = try await collectStream(retryPrompt)
                lastResponseTime = Date().timeIntervalSince(start)
                let retryContent = isSuspiciousResponse(retryResponse)
                    ? "⚠️ Security Warning: The AI generated a response that appeared to request sensitive information. This response has been blocked."
                    : retryResponse
                updateMessage(at: msgIndex, content: retryContent, isStreaming: false)
                if activeConversation?.messages.count == 2,
                   let title = activeConversation?.messages.first?.content {
                    activeConversation?.title = String(title.prefix(40))
                }
                currentSuggestions = SuggestionEngine.suggestions(
                    for: retryResponse,
                    userMessage: trimmed,
                    walletHasBalance: (walletVM?.solBalance ?? 0) > 0
                )
            } catch {
                updateMessage(at: msgIndex,
                              content: "⚠️ The conversation context window was exceeded and could not be recovered. Please start a new chat (⌘K) and repeat your request.",
                              isStreaming: false)
                confirmationHandlerRef?.clearPending()
            }
            isProcessing = false
            persistActive()
            aiSession.reset()   // clean slate for next user message
            return
        } catch {
            updateMessage(at: msgIndex, content: error.localizedDescription, isStreaming: false)
            confirmationHandlerRef?.clearPending()
            if error.localizedDescription.contains("not available") ||
               error.localizedDescription.contains("not initialized") {
                aiUnavailable = true
            }
        }

        isProcessing = false
        persistActive()
        aiSession.reset()   // clean slate for next user message
    }

    // MARK: - Conversation Management

    func newConversation() {
        let convo = Conversation()
        conversations.insert(convo, at: 0)
        activeConversation = convo
        aiSession.reset()
        hasInjectedContext = false
        currentSuggestions = []
        lastResponseTime = nil
        sessionMessageCount = 0
        sessionTransactionCount = 0
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
    /// Subsequent messages are sent as-is (context already in transcript).
    private func buildContextualPrompt(userText: String) -> String {
        guard !hasInjectedContext,
              let wvm = walletVM,
              wvm.isWalletReady else { return userText }

        hasInjectedContext = true

        let tokenSummary = wvm.tokenBalances.map {
            (symbol: $0.symbol, uiAmount: $0.uiAmount, usdValue: $0.usdValue)
        }
        return AIInstructions.contextBlock(
            walletAddress: wvm.publicKey ?? "unknown",
            solBalance: wvm.solBalance,
            solUSDValue: wvm.solUSDValue,
            tokenBalances: tokenSummary,
            statsContext: statsVM?.contextSummary ?? "",
            userMessage: userText
        )
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

    private func streamWithRecovery(_ prompt: String) async throws -> String {
        do {
            return try await collectStream(prompt)
        } catch {
            if isContextWindowError(error) {
                aiSession.reset()
                throw AIError.contextWindowExceeded
            }
            throw error
        }
    }

    private func isContextWindowError(_ error: Error) -> Bool {
        if case AIError.contextWindowExceeded = error { return true }
        let text = error.localizedDescription.lowercased()
        // Apple FoundationModels error text: "Context length of 4096 was exceeded during singleExtend."
        return text.contains("4096")
            || text.contains("context length")
            || text.contains("context window")
            || text.contains("exceeded")
            || text.contains("singleextend")
            || text.contains("inferencefailed")
            || text.contains("generationerror")
            || text.contains("error -1")
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
