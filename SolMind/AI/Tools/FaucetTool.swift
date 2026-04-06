import FoundationModels
import Foundation

// MARK: - Faucet Tool

struct FaucetTool: Tool {
    let name = "getFromFaucet"
    let description = "Request free devnet SOL from the Solana faucet. Maximum 2 SOL per request. Only works on devnet."

    @MainActor private let walletManager: WalletManager
    private let solanaClient: SolanaClient

    init(walletManager: WalletManager, solanaClient: SolanaClient) {
        self.walletManager = walletManager
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "Amount of SOL to request (max 2.0). Defaults to 1.0.")
        var amount: Double?
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        let requestedSOL = min(arguments.amount ?? 1.0, 2.0)
        let lamports = UInt64(requestedSOL * 1_000_000_000)

        let signature = try await solanaClient.requestAirdrop(to: publicKey, lamports: lamports)
        return """
        ⚠️ DEVNET: Airdrop of \(requestedSOL) SOL requested successfully!
        Transaction: \(signature)
        Explorer: \(SolanaNetwork.explorerURL(signature: signature).absoluteString)
        Note: It may take a few seconds for the balance to update.
        """
    }
}
