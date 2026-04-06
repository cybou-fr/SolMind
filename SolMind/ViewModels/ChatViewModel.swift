import Foundation

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
        let tools: [any Tool] = [
            BalanceTool(walletManager: walletManager, solanaClient: solanaClient),
            FaucetTool(walletManager: walletManager, solanaClient: solanaClient),
            SendTool(walletManager: walletManager, solanaClient: solanaClient),
            PriceTool(),
            SwapTool(walletManager: walletManager, solanaClient: solanaClient),
            NFTTool(walletManager: walletManager),
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
            var fullResponse = ""
            for try await chunk in aiSession.stream(trimmed) {
                fullResponse += chunk
                activeConversation?.messages[msgIndex].content = fullResponse
            }
            activeConversation?.messages[msgIndex].isStreaming = false

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
    }

    func deleteConversation(_ convo: Conversation) {
        conversations.removeAll { $0.id == convo.id }
        if activeConversation?.id == convo.id {
            activeConversation = conversations.first
        }
    }
}
