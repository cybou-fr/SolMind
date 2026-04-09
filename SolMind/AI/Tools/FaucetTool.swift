import FoundationModels
import Foundation

// MARK: - Faucet Tool

struct FaucetTool: Tool {
    let name = "getFromFaucet"
    let description = "Request free devnet SOL airdrop. Max 2 SOL per request."

    private let walletManager: WalletManager
    private let solanaClient: SolanaClient

    init(walletManager: WalletManager, solanaClient: SolanaClient) {
        self.walletManager = walletManager
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "SOL amount (max 2, default 1)")
        var amount: Double?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        let requestedSOL = min(arguments.amount ?? 1.0, 2.0)
        let lamports = UInt64(requestedSOL * 1_000_000_000)

        // Three truly distinct RPC endpoints — different providers, different rate limits.

        // 1. Solana Foundation public devnet (always available, independent of any API key)
        let publicClient = SolanaClient(rpcURL: URL(string: "https://api.devnet.solana.com")!)
        if let sig = try? await publicClient.requestAirdrop(to: publicKey, lamports: lamports) {
            await MainActor.run { ToastManager.shared.success("✓ \(requestedSOL) devnet SOL incoming!") }
            return "⚠️ DEVNET: Airdrop of \(requestedSOL) SOL requested! TX: \(sig.prefix(12))…"
        }

        // 2. Helius devnet RPC (separate provider + rate limit)
        let heliusKey = AppSettings.shared.effectiveHeliusAPIKey
        let heliusURL = URL(string: "https://devnet.helius-rpc.com/?api-key=\(heliusKey)")!
        let heliusClient = SolanaClient(rpcURL: heliusURL)
        if let sig = try? await heliusClient.requestAirdrop(to: publicKey, lamports: lamports) {
            await MainActor.run { ToastManager.shared.success("✓ \(requestedSOL) devnet SOL incoming!") }
            return "⚠️ DEVNET: Airdrop of \(requestedSOL) SOL requested! TX: \(sig.prefix(12))…"
        }

        // 3. Ankr devnet RPC (third independent provider)
        let ankrClient = SolanaClient(rpcURL: URL(string: "https://rpc.ankr.com/solana_devnet")!)
        if let sig = try? await ankrClient.requestAirdrop(to: publicKey, lamports: lamports) {
            await MainActor.run { ToastManager.shared.success("✓ \(requestedSOL) devnet SOL incoming!") }
            return "⚠️ DEVNET: Airdrop of \(requestedSOL) SOL requested! TX: \(sig.prefix(12))…"
        }

        // 4. All providers rate-limited — guide the user to web faucets
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
