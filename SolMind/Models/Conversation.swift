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
