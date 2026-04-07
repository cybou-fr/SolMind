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

    private let aiSession = AISession()
    private let solanaClient = SolanaClient()
    private let store = ConversationStore()

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
            OnRampTool(walletManager: walletManager)
        ]
        aiSession.initialize(tools: tools)
    }

    // MARK: - Send Message

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed, timestamp: Date())
        activeConversation?.messages.append(userMessage)
        inputText = ""
        isProcessing = true
        currentSuggestions = []

        var assistantMsg = ChatMessage(role: .assistant, content: "", timestamp: Date(), isStreaming: true)
        activeConversation?.messages.append(assistantMsg)
        let msgIndex = (activeConversation?.messages.count ?? 1) - 1

        do {
            // Build contextual prompt (injects wallet/network context on first message)
            let prompt = buildContextualPrompt(userText: trimmed)

            let start = Date()
            let fullResponse = try await streamWithRecovery(prompt)
            lastResponseTime = Date().timeIntervalSince(start)

            activeConversation?.messages[msgIndex].content = fullResponse
            activeConversation?.messages[msgIndex].isStreaming = false

            // Security: block responses that solicit sensitive credentials
            if isSuspiciousResponse(fullResponse) {
                activeConversation?.messages[msgIndex].content = """
                ⚠️ Security Warning: The AI generated a response that appeared to request sensitive information (private key or seed phrase). This response has been blocked.

                SolMind will NEVER ask for your private key. If you see such a request, it is a scam attempt. Your wallet is managed securely on-device.
                """
            }

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

        } catch AIError.contextWindowExceeded {
            activeConversation?.messages[msgIndex].content = """
            ⚠️ The conversation became too long and the context window was exceeded. \
            The session has been reset automatically.

            **Your last action was NOT executed.** Please start a new chat (⌘K) and repeat your request.
            """
            activeConversation?.messages[msgIndex].isStreaming = false
            isProcessing = false
            persistActive()
            newConversation()
            return
        } catch {
            activeConversation?.messages[msgIndex].content = error.localizedDescription
            activeConversation?.messages[msgIndex].isStreaming = false
            if error.localizedDescription.contains("not available") ||
               error.localizedDescription.contains("not initialized") {
                aiUnavailable = true
            }
        }

        isProcessing = false
        persistActive()
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

        return AIInstructions.contextBlock(
            walletAddress: wvm.publicKey ?? "unknown",
            solBalance: wvm.solBalance,
            solUSDValue: wvm.solUSDValue,
            tokenCount: wvm.tokenBalances.count,
            statsContext: statsVM?.contextSummary ?? "",
            userMessage: userText
        )
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
        return text.contains("4096")
            || text.contains("context length")
            || text.contains("context window")
            || text.contains("exceeded")
            || text.contains("generationerror")
            || text.contains("error -1")
    }

    private func collectStream(_ prompt: String) async throws -> String {
        var result = ""
        for try await chunk in aiSession.stream(prompt) {
            result = chunk
            // Update streaming content in real-time
            let msgIndex = (activeConversation?.messages.count ?? 1) - 1
            if msgIndex >= 0 {
                activeConversation?.messages[msgIndex].content = result
            }
        }
        return result
    }

    // MARK: - Security

    private func isSuspiciousResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        let privateKeyPhrases = [
            "private key", "seed phrase", "mnemonic", "secret key",
            "clé privée", "phrase secrète",
            "provide your", "share your key", "enter your key",
            "including your private", "wallet secret"
        ]
        return privateKeyPhrases.contains { lower.contains($0) }
    }
}
