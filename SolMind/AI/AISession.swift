import Foundation
import Observation
import FoundationModels

@Observable
class AISession {
    private var session: LanguageModelSession?
    private var tools: [any Tool] = []
    private(set) var isAvailable = false

    // MARK: - Availability

    /// Checks whether the on-device model can actually run.
    /// Returns nil when available, or a human-readable reason string when not.
    func checkAvailability() -> String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This device doesn't support Apple Intelligence. Apple Silicon is required."
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled. Go to Settings → Apple Intelligence & Siri to turn it on."
            case .modelNotReady:
                return "Apple Intelligence model is still downloading. Please wait a few minutes and try again."
            @unknown default:
                return "Apple Intelligence is unavailable on this device or configuration."
            }
        }
    }

    // MARK: - Initialization

    func initialize(tools: [any Tool] = []) {
        self.tools = tools
        createSession()
        isAvailable = true
    }

    /// Tear down and recreate the session (clears transcript / context window)
    func reset() {
        createSession()
    }

    private func createSession() {
        // IMPORTANT: Do NOT inject raw base58 addresses anywhere in Instructions or prompts.
        // Apple's on-device language classifier treats base58 clusters as Catalan/Slovak/etc.
        // and throws GenerationError.unsupportedLanguageOrLocale. All address resolution is
        // handled inside individual tool implementations, never in static text.
        let instructions = Instructions(AIInstructions.system)
        if tools.isEmpty {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession(tools: tools, instructions: instructions)
        }
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
            let task = Task {
                do {
                    for try await partial in session.streamResponse(to: prompt) {
                        // Stop yielding if the consumer has already cancelled.
                        if Task.isCancelled { break }
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Cancel the inner Task when the stream consumer stops (cancellation or early exit).
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case notInitialized
    case modelUnavailable
    case contextWindowExceeded

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "AI session not initialized."
        case .modelUnavailable:
            return "On-device model not available. Enable Apple Intelligence in System Settings."
        case .contextWindowExceeded:
            return "The conversation context window was exceeded. A new session has been started — please repeat your last request."
        }
    }
}
