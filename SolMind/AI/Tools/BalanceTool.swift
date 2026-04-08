import FoundationModels
import Foundation

// MARK: - Balance Tool

struct BalanceTool: Tool {
    let name = "getBalance"
    let description = "Get the SOL or SPL token balance of the connected wallet. Pass nil for tokenMint to get SOL balance."

    private let walletManager: WalletManager
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

    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        do {
            if let mint = arguments.tokenMint, !mint.isEmpty {
                let accounts = try await solanaClient.getTokenAccounts(owner: publicKey)
                if let account = accounts.first(where: { $0.mint == mint }) {
                    return "Token balance for mint \(mint): \(account.displayAmount) [DEVNET]"
                }
                // Also fetch SOL so the model has full context
                let sol = try await solanaClient.getSOLBalance(publicKey: publicKey)
                return "No token account found for mint \(mint) on devnet. Current SOL balance: \(String(format: "%.6f", sol)) SOL. The wallet may not have received this token yet — use the faucet to get SOL first, then acquire tokens via swap."
            } else {
                let balance = try await solanaClient.getSOLBalance(publicKey: publicKey)
                let tokenAccounts = try await solanaClient.getTokenAccounts(owner: publicKey)
                var result = String(format: "SOL balance: %.9f SOL [DEVNET] | Address: %@", balance, publicKey)
                if balance == 0 {
                    result += " | EMPTY WALLET: Call getFromFaucet tool now to fund this wallet with devnet SOL."
                }
                if !tokenAccounts.isEmpty {
                    let tokenSummary = tokenAccounts.map { "\($0.mint): \($0.displayAmount)" }.joined(separator: ", ")
                    result += " | SPL tokens: \(tokenSummary)"
                }
                return result
            }
        } catch {
            return "Failed to fetch balance: \(error.localizedDescription)"
        }
    }
}
