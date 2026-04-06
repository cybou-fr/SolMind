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

    // MARK: - Called by tools (any isolation)

    /// Suspends the calling tool until the user taps Confirm or Cancel.
    /// Safe to call from any actor context; switches to MainActor internally.
    nonisolated func requestConfirmation(_ preview: TransactionPreview) async -> Bool {
        await withCheckedContinuation { cont in
            Task { @MainActor in
                // If another confirmation is unexpectedly pending, cancel it first.
                self.continuation?.resume(returning: false)
                self.pendingPreview = preview
                self.continuation = cont
            }
        }
    }

    // MARK: - Called by UI (MainActor)

    func confirm() {
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
}
