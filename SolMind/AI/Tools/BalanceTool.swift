import FoundationModels
import Foundation

// MARK: - Balance Tool

struct BalanceTool: Tool {
    let name = "getBalance"
    let description = "Get the SOL or SPL token balance of the connected wallet. Pass nil for tokenMint to get SOL balance."

    @MainActor private let walletManager: WalletManager
    private let solanaClient: SolanaClient

    init(walletManager: WalletManager, solanaClient: SolanaClient) {
        self.walletManager = walletManager
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "Optional SPL token mint address. Omit for SOL balance.")
        var tokenMint: String?
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        if let mint = arguments.tokenMint, !mint.isEmpty {
            let accounts = try await solanaClient.getTokenAccounts(owner: publicKey)
            if let account = accounts.first(where: { $0.mint == mint }) {
                return "Token balance (\(mint)): \(account.displayAmount) [DEVNET]"
            }
            return "No token account found for mint \(mint) on devnet."
        } else {
            let balance = try await solanaClient.getSOLBalance(publicKey: publicKey)
            return String(format: "SOL balance: %.9f SOL [DEVNET] (Address: %@)", balance, publicKey)
        }
    }
}
