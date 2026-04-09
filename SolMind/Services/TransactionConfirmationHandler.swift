import Foundation
import Observation

// MARK: - Transaction Confirmation Handler
//
// Bridges AI Tools (which run on non-MainActor threads during a Foundation Models
// session) to the native SwiftUI confirmation card shown in ChatView.
//
// Flow:
//   1. Tool calls `await requestConfirmation(_:)` — suspends the tool's async task.
//   2. Handler sets `pendingPreview` on MainActor, which SwiftUI observes.
//   3. ChatView displays TransactionPreviewCard.
//   4. User taps Confirm → `confirm()` → continuation resumes with `true`.
//      User taps Cancel  → `cancel()`  → continuation resumes with `false`.
//   5. Tool receives the Bool and either executes or abandons the transaction.

@Observable
@MainActor
final class TransactionConfirmationHandler {

    /// Non-nil when a tool is waiting for the user to confirm a transaction.
    var pendingPreview: TransactionPreview? = nil

    private var continuation: CheckedContinuation<Bool, Never>? = nil

    /// After the user taps Confirm, we lock new confirmations for this duration.
    /// This prevents the FoundationModels model from retrying a failed tool call and
    /// showing a duplicate confirmation popup in a loop.
    private var lockedUntil: Date? = nil
    private static let lockoutDuration: TimeInterval = 12

    // MARK: - Called by tools (any isolation)

    /// Suspends the calling tool until the user taps Confirm or Cancel.
    /// Safe to call from any actor context; switches to MainActor internally.
    nonisolated func requestConfirmation(_ preview: TransactionPreview) async -> Bool {
        await withCheckedContinuation { cont in
            Task { @MainActor in
                // If a recent confirmation was already acted on, reject retry attempts
                // to prevent AI-driven loops (model retrying a failed transaction).
                if let locked = self.lockedUntil, Date() < locked {
                    cont.resume(returning: false)
                    return
                }
                // If another confirmation is unexpectedly pending, cancel it first.
                self.continuation?.resume(returning: false)
                self.pendingPreview = preview
                self.continuation = cont
            }
        }
    }

    // MARK: - Called by UI (MainActor)

    func confirm() {
        // Lock new confirmations briefly so a failing tool can't immediately re-popup.
        lockedUntil = Date().addingTimeInterval(Self.lockoutDuration)
        let cont = continuation
        pendingPreview = nil
        continuation = nil
        cont?.resume(returning: true)
    }

    func cancel() {
        let cont = continuation
        pendingPreview = nil
        continuation = nil
        cont?.resume(returning: false)
    }

    /// Clears any pending confirmation without user action (e.g. when the AI stream is
    /// cancelled mid-flight). The suspended tool receives `false` and aborts the transaction.
    func clearPending() {
        let cont = continuation
        pendingPreview = nil
        continuation = nil
        lockedUntil = nil
        cont?.resume(returning: false)
    }

    /// Called at the start of a new user message so legitimate follow-up
    /// transactions after a successful one are never blocked.
    func resetLockout() {
        lockedUntil = nil
    }
}
