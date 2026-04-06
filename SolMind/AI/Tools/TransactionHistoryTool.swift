import FoundationModels
import Foundation

// MARK: - Transaction History Tool

struct TransactionHistoryTool: Tool {
    let name = "getTransactionHistory"
    let description = "Get recent transaction history for the connected wallet."

    private let walletManager: WalletManager
    private let solanaClient: SolanaClient

    init(walletManager: WalletManager, solanaClient: SolanaClient) {
        self.walletManager = walletManager
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "Number of transactions to return (max 20, default 5)")
        var limit: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        let limit = min(arguments.limit ?? 5, 20)
        do {
            let signatures = try await solanaClient.getSignaturesForAddress(publicKey: publicKey, limit: limit)

            if signatures.isEmpty {
                return "No transactions found for your devnet wallet."
            }

            let lines = signatures.map { sig -> String in
                let status = sig.err == nil ? "✅" : "❌"
                let dateStr: String
                if let bt = sig.blockTime {
                    let date = Date(timeIntervalSince1970: TimeInterval(bt))
                    dateStr = date.formatted(.relative(presentation: .named))
                } else {
                    dateStr = "unknown time"
                }
                return "\(status) \(sig.signature.prefix(8))… — \(dateStr)"
            }.joined(separator: "\n")

            return "Recent transactions (\(signatures.count)):\n\(lines)"
        } catch {
            return "Could not fetch transaction history: \(error.localizedDescription)"
        }
    }
}
