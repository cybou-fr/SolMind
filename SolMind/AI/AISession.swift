import FoundationModels

@Observable
class AISession {
    private var session: LanguageModelSession?
    private(set) var isAvailable = false

    // MARK: - Initialization

    func initialize(tools: [any ToolProtocol] = []) {
        let instructions = LanguageModelSession.Instructions(systemPrompt: AIInstructions.system)
        session = LanguageModelSession(instructions: instructions)
        isAvailable = true
    }

    // MARK: - Single Response

    func send(_ prompt: String) async throws -> String {
        guard let session else { throw AIError.notInitialized }
        let response = try await session.respond(to: Prompt(prompt))
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
                    let stream = session.streamResponse(to: Prompt(prompt))
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Placeholder protocol for tools (replaced with FoundationModels.Tool in Phase 3)
protocol ToolProtocol {}

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
