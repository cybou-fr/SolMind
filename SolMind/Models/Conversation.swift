import Foundation

@Observable
class Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, messages, createdAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let msgs = try container.decode([ChatMessage].self, forKey: .messages)
        // Never restore mid-stream messages
        messages = msgs.map { msg in
            var m = msg
            m.isStreaming = false
            return m
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        // Don't persist streaming messages
        let persistable = messages.filter { !$0.isStreaming }
        try container.encode(persistable, forKey: .messages)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
