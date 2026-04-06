import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool = false

    init(role: Role, content: String, timestamp: Date, isStreaming: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    enum Role: Codable {
        case user
        case assistant
        case tool(name: String)
        case error
    }
}
