import FoundationModels
import Foundation

// MARK: - Swap Tool (Jupiter DEX)

struct SwapTool: Tool {
    let name = "swapTokens"
    let description = "Swap tokens using Jupiter DEX aggregator on Solana devnet. Provide fromToken and toToken as symbols (e.g. SOL, USDC) or mint addresses, and the amount to swap."

    @MainActor private let walletManager: WalletManager
    private let jupiterService: JupiterService
    private let solanaClient: SolanaClient

    init(walletManager: WalletManager, jupiterService: JupiterService, solanaClient: SolanaClient) {
        self.walletManager = walletManager
        self.jupiterService = jupiterService
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "Source token symbol or mint address (e.g. SOL)")
        var fromToken: String
        @Guide(description: "Destination token symbol or mint address (e.g. USDC)")
        var toToken: String
        @Guide(description: "Amount to swap in token units")
        var amount: Double
        @Guide(description: "Set to true only after user confirmed the swap preview")
        var confirmed: Bool?
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        guard walletManager.isConnected else {
            return "Wallet not connected."
        }

        let fromMint = JupiterService.mintForSymbol(arguments.fromToken)
        let toMint = JupiterService.mintForSymbol(arguments.toToken)

        let decimals = arguments.fromToken.uppercased() == "SOL" ? 9 : 6
        let rawAmount = UInt64(arguments.amount * pow(10.0, Double(decimals)))

        let quote: SwapQuote
        do {
            quote = try await jupiterService.getQuote(
                inputMint: fromMint,
                outputMint: toMint,
                amount: rawAmount
            )
        } catch {
            return "Could not get swap quote: \(error.localizedDescription). Note: Devnet Jupiter liquidity is limited."
        }

        let outDecimals = arguments.toToken.uppercased() == "SOL" ? 9 : 6
        let outAmount = (Double(quote.outAmount) ?? 0) / pow(10.0, Double(outDecimals))

        if arguments.confirmed != true {
            return """
            ⚠️ DEVNET SWAP PREVIEW:
            From: \(arguments.amount) \(arguments.fromToken.uppercased())
            To: ≈\(String(format: "%.6f", outAmount)) \(arguments.toToken.uppercased())
            Price Impact: \(String(format: "%.2f", quote.priceImpactPct))%
            Route: \(quote.routePlan.map { $0.swapInfo.label }.joined(separator: " → "))
            
            Reply with confirmed: true to confirm the swap.
            """
        }

        // Execute swap
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }
        let swapData = try await jupiterService.getSwapTransaction(quote: quote, userPublicKey: publicKey)
        let signature = try await solanaClient.sendTransaction(serialized: swapData)
        return """
        ✅ DEVNET: Swap executed!
        Signature: \(signature)
        Explorer: \(SolanaNetwork.explorerURL(signature: signature).absoluteString)
        """
    }
}
