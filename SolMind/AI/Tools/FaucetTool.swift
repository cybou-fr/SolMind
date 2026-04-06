import FoundationModels
import Foundation

// MARK: - Faucet Tool

struct FaucetTool: Tool {
    let name = "getFromFaucet"
    let description = "Request free devnet SOL from the Solana faucet. Maximum 2 SOL per request. Only works on devnet."

    private let walletManager: WalletManager
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

    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        let requestedSOL = min(arguments.amount ?? 1.0, 2.0)
        let lamports = UInt64(requestedSOL * 1_000_000_000)

        // 1. Try public devnet RPC
        if let sig = try? await solanaClient.requestAirdrop(to: publicKey, lamports: lamports) {
            return """
            ⚠️ DEVNET: Airdrop of \(requestedSOL) SOL requested!
            Transaction: \(sig)
            Explorer: \(SolanaNetwork.explorerURL(signature: sig).absoluteString)
            """
        }

        // 2. Fall back to Helius devnet RPC (separate rate limit)
        let heliusURL = URL(string: "https://devnet.helius-rpc.com/?api-key=\(Secrets.heliusAPIKey)")!
        let heliusClient = SolanaClient(rpcURL: heliusURL)
        if let sig = try? await heliusClient.requestAirdrop(to: publicKey, lamports: lamports) {
            return """
            ⚠️ DEVNET: Airdrop of \(requestedSOL) SOL requested via Helius!
            Transaction: \(sig)
            Explorer: \(SolanaNetwork.explorerURL(signature: sig).absoluteString)
            """
        }

        // 3. Both rate-limited — guide the user to web faucets
        return """
        The devnet faucet is currently rate-limited for your address. Please get SOL from one of these web faucets:

        • https://faucet.solana.com — Official Solana Foundation faucet
        • https://faucet.quicknode.com/solana/devnet — QuickNode devnet faucet
        • https://solfaucet.com — SolFaucet.com

        For devnet USDC, use Circle's dedicated faucet:
        • https://faucet.circle.com — Provides devnet USDC (paste your wallet address)

        Your wallet address: \(publicKey)
        """
    }
}
