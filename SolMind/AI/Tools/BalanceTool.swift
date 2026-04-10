import FoundationModels
import Foundation

// MARK: - Balance Tool

struct BalanceTool: Tool {
    let name = "getBalance"
    let description = "Get SOL and SPL token balances for the active wallet."

    private let walletManager: WalletManager
    private let solanaClient: SolanaClient

    init(walletManager: WalletManager, solanaClient: SolanaClient) {
        self.walletManager = walletManager
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "SPL mint address (nil = SOL)")
        var tokenMint: String?
    }

    // MARK: - Known token symbols (devnet + mainnet mints)
    private static let knownMints: [String: String] = [
        "So11111111111111111111111111111111111111112": "SOL",
        "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": "USDC",
        "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB": "USDT",
        "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU": "USDC(dev)"
    ]

    private func knownSymbol(for mint: String) -> String {
        Self.knownMints[mint] ?? "\(mint.prefix(6))…"
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
                    // Show symbol (or abbreviated mint) + amount — avoid raw 44-char mints to save context tokens
                    let tokenSummary = tokenAccounts.map { acct -> String in
                        let sym = knownSymbol(for: acct.mint)
                        return "\(sym): \(acct.displayAmount)"
                    }.joined(separator: ", ")
                    result += " | SPL tokens: \(tokenSummary)"
                }
                return result
            }
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("timed out") || msg.contains("network") || msg.contains("offline") || msg.contains("connection") {
                return "Network error: Could not reach the Solana RPC. Check your internet connection and try again."
            } else if msg.contains("429") || msg.contains("rate") {
                return "RPC rate limit reached. Wait a moment and try again."
            } else if msg.contains("403") || msg.contains("401") {
                return "RPC authentication error. Check your API key in Settings."
            }
            return "Failed to fetch balance: \(error.localizedDescription)"
        }
    }
}
