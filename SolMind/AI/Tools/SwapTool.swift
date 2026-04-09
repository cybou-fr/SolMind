import FoundationModels
import Foundation

// MARK: - Swap Tool (Jupiter DEX)

struct SwapTool: Tool {
    let name = "swapTokens"
    let description = "Swap tokens via Jupiter DEX. Devnet has no liquidity (will fail). Requires confirmation."

    private let walletManager: WalletManager
    private let jupiterService: JupiterService
    private let solanaClient: SolanaClient
    private let confirmationHandler: TransactionConfirmationHandler

    init(walletManager: WalletManager, jupiterService: JupiterService, solanaClient: SolanaClient, confirmationHandler: TransactionConfirmationHandler) {
        self.walletManager = walletManager
        self.jupiterService = jupiterService
        self.solanaClient = solanaClient
        self.confirmationHandler = confirmationHandler
    }

    @Generable
    struct Arguments {
        @Guide(description: "Source token symbol or mint")
        var fromToken: String
        @Guide(description: "Destination token symbol or mint")
        var toToken: String
        @Guide(description: "Amount to swap")
        var amount: Double
    }

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
            // Jupiter runs on mainnet only — devnet has no liquidity pools, so quotes always fail.
            return """
            ⚠️ **Swap unavailable on devnet**

            Jupiter DEX runs on Solana **mainnet** only — devnet has no liquidity pools, \
            so swap quotes always fail here. This is expected during devnet testing.

            **Alternatives on devnet:**
            • Get free devnet USDC at https://faucet.circle.com (paste your wallet address)
            • Use "create token" to mint your own test tokens
            • Swaps will work normally when the app switches to mainnet

            Technical detail: \(error.localizedDescription)
            """
        }

        let outDecimals = arguments.toToken.uppercased() == "SOL" ? 9 : 6
        let outAmount = (Double(quote.outAmount) ?? 0) / pow(10.0, Double(outDecimals))
        let route = quote.routePlan.map { $0.swapInfo.label }.joined(separator: " → ")

        let preview = TransactionPreview(
            action: "swap",
            amount: arguments.amount,
            tokenSymbol: arguments.fromToken.uppercased(),
            recipient: "",
            estimatedFee: 0.000005,
            summary: "⚠️ DEVNET — Swap \(arguments.amount) \(arguments.fromToken.uppercased()) → ≈\(String(format: "%.6f", outAmount)) \(arguments.toToken.uppercased()) via \(route)"
        )

        // Show native confirmation card and suspend until user responds.
        let confirmed = await confirmationHandler.requestConfirmation(preview)
        guard confirmed else {
            return "Swap cancelled by user."
        }

        // Execute swap
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }
        await MainActor.run { ToastManager.shared.info("Executing swap…") }
        do {
            let swapData = try await jupiterService.getSwapTransaction(quote: quote, userPublicKey: publicKey)
            let signature = try await solanaClient.sendTransaction(serialized: swapData)
            guard signature.count >= 80, Base58.decode(signature) != nil else {
                await MainActor.run { ToastManager.shared.warning("Swap submitted but response was unexpected — verify on Explorer.") }
                return "⚠️ DEVNET: sendTransaction returned an unexpected response. The swap may not have been submitted. Check the explorer manually."
            }
            await MainActor.run { ToastManager.shared.success("✓ Swap executed!") }
            return "✅ DEVNET: Swap executed! TX: \(signature.prefix(12))…"
        } catch {
            await MainActor.run { ToastManager.shared.error("Swap failed: \(error.localizedDescription)") }
            return "Swap execution failed: \(error.localizedDescription)"
        }
    }
}
