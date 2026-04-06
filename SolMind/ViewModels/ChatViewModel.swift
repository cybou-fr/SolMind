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

    private let aiSession = AISession()
    private let solanaClient = SolanaClient()
    private let store = ConversationStore()

    init() {
        // Will load from disk in loadPersistedConversations(); start with one fresh conversation
        let initial = Conversation(title: "New Chat")
        conversations.append(initial)
        activeConversation = initial
        // setupAI(walletManager:) must be called after WalletViewModel is available
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

    /// Call after every message to persist changes.
    private func persistActive() {
        guard let convo = activeConversation else { return }
        try? store.save(convo)
    }

    // MARK: - AI Setup

    func setupAI(walletManager: WalletManager) {
        let jupiterService = JupiterService()
        let heliusService = HeliusService()
        let tools: [any Tool] = [
            BalanceTool(walletManager: walletManager, solanaClient: solanaClient),
            FaucetTool(walletManager: walletManager, solanaClient: solanaClient),
            SendTool(walletManager: walletManager, solanaClient: solanaClient),
            PriceTool(),
            SwapTool(walletManager: walletManager, jupiterService: jupiterService, solanaClient: solanaClient),
            NFTTool(walletManager: walletManager, heliusService: heliusService),
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

        // Placeholder for streaming assistant response
        var assistantMsg = ChatMessage(role: .assistant, content: "", timestamp: Date(), isStreaming: true)
        activeConversation?.messages.append(assistantMsg)
        let msgIndex = (activeConversation?.messages.count ?? 1) - 1

        do {
            var fullResponse = try await streamWithRecovery(trimmed)
            activeConversation?.messages[msgIndex].content = fullResponse
            activeConversation?.messages[msgIndex].isStreaming = false

            // Security: block any response that attempts to solicit sensitive credentials
            if isSuspiciousResponse(fullResponse) {
                activeConversation?.messages[msgIndex].content = """
                ⚠️ Security Warning: The AI generated a response that appeared to request sensitive information (private key or seed phrase). This response has been blocked.

                SolMind will NEVER ask for your private key. If you see such a request, it is a scam attempt. Your wallet is managed securely on-device.
                """
            }

            // Auto-title conversation from first message
            if activeConversation?.messages.count == 2,
               let title = activeConversation?.messages.first?.content {
                activeConversation?.title = String(title.prefix(40))
            }
        } catch AIError.contextWindowExceeded {
            // Context overflow: session has been reset. Do NOT retry — a silent retry after
            // context clear could cause transaction tools to fabricate success.
            activeConversation?.messages[msgIndex].content = """
            ⚠️ The conversation became too long and the context window was exceeded. \
            The session has been reset automatically.

            **Your last action was NOT executed.** Please start a new chat (⌘K) and repeat your request.
            """
            activeConversation?.messages[msgIndex].isStreaming = false
            isProcessing = false
            persistActive()
            // Start a fresh conversation so the next message has a clean context
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
        aiSession.reset() // fresh context window for each conversation
    }

    func deleteConversation(_ convo: Conversation) {
        let id = convo.id
        conversations.removeAll { $0.id == id }
        if activeConversation?.id == id {
            activeConversation = conversations.first
        }
        try? store.delete(id)
    }

    // MARK: - Streaming with context-window recovery

    /// Streams a response. If the session hits a context-window overflow, resets the
    /// session and throws `AIError.contextWindowExceeded` — callers must NOT retry
    /// automatically because doing so after a reset produces hallucinated responses
    /// (the AI has no context of what tool call or transaction was in progress).
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

    /// Detects context-window overflow errors from Foundation Models.
    /// Matches both the system-level message ("4096", "exceeded", "context") and
    /// any GenerationError description that older beta builds produce.
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
            // partial.content is the full accumulated text so far — replace, don't append
            result = chunk
        }
        return result
    }

    // MARK: - Security

    private func isSuspiciousResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        let privateKeyPhrases = [
            "private key", "seed phrase", "mnemonic", "secret key",
            "clé privée", "phrase secrète",  // French variants
            "provide your", "share your key", "enter your key",
            "including your private", "wallet secret"
        ]
        return privateKeyPhrases.contains { lower.contains($0) }
    }
}
