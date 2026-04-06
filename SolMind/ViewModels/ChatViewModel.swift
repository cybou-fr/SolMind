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

    init() {
        let initial = Conversation(title: "New Chat")
        conversations.append(initial)
        activeConversation = initial
        // setupAI(walletManager:) must be called after WalletViewModel is available
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
        } catch {
            activeConversation?.messages[msgIndex].content = error.localizedDescription
            activeConversation?.messages[msgIndex].isStreaming = false
            if error.localizedDescription.contains("not available") ||
               error.localizedDescription.contains("not initialized") {
                aiUnavailable = true
            }
        }

        isProcessing = false
    }

    // MARK: - Conversation Management

    func newConversation() {
        let convo = Conversation()
        conversations.insert(convo, at: 0)
        activeConversation = convo
        aiSession.reset() // fresh context window for each conversation
    }

    func deleteConversation(_ convo: Conversation) {
        conversations.removeAll { $0.id == convo.id }
        if activeConversation?.id == convo.id {
            activeConversation = conversations.first
        }
    }

    // MARK: - Streaming with context-window recovery

    /// Streams a response; if the session hits a GenerationError (context overflow),
    /// resets the session and retries once with just the current message.
    private func streamWithRecovery(_ prompt: String) async throws -> String {
        do {
            return try await collectStream(prompt)
        } catch {
            let isGenerationError = error.localizedDescription.contains("GenerationError") ||
                                    error.localizedDescription.contains("error -1")
            if isGenerationError {
                aiSession.reset()
                return try await collectStream(prompt)
            }
            throw error
        }
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
