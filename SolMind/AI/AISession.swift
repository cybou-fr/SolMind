import FoundationModels

@Observable
class AISession {
    private var session: LanguageModelSession?
    private(set) var isAvailable = false

    // MARK: - Initialization

    func initialize(tools: [any Tool] = []) {
        let instructions = LanguageModelSession.Instructions(AIInstructions.system)
        if tools.isEmpty {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession(tools: tools, instructions: instructions)
        }
        isAvailable = true
    }

    // MARK: - Single Response

    func send(_ prompt: String) async throws -> String {
        guard let session else { throw AIError.notInitialized }
        let response = try await session.respond(to: prompt)
        return response.content
    }

    // MARK: - Streaming Response

    func stream(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let session else {
                continuation.finish(throwing: AIError.notInitialized)
                return
            }
            Task {
                do {
                    for try await partial in session.streamResponse(to: prompt) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case notInitialized
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "AI session not initialized."
        case .modelUnavailable:
            return "On-device model not available. Enable Apple Intelligence in System Settings."
        }
    }
}
