import Foundation

// MARK: - Conversation Persistence (JSON files in Application Support)
// @MainActor so we can directly encode/decode @Observable Conversation objects.

@MainActor
final class ConversationStore {
    private let directory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appending(path: "fr.cybou.SolMind/conversations", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Save

    func save(_ conversation: Conversation) throws {
        let url = fileURL(for: conversation.id)
        let data = try JSONEncoder().encode(conversation)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Load all

    func loadAll() throws -> [Conversation] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        let decoder = JSONDecoder()
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Conversation? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Conversation.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Delete

    func delete(_ id: UUID) throws {
        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }
}
