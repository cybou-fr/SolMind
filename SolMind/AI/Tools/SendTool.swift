import FoundationModels
import Foundation

// MARK: - Send Tokens Tool

struct SendTool: Tool {
    let name = "sendTokens"
    let description = "Send SOL or SPL tokens to a recipient address. Shows a native confirmation card before executing — never ask the user to type 'confirmed: true' or similar text."

    private let walletManager: WalletManager
    private let solanaClient: SolanaClient
    private let confirmationHandler: TransactionConfirmationHandler

    init(walletManager: WalletManager, solanaClient: SolanaClient, confirmationHandler: TransactionConfirmationHandler) {
        self.walletManager = walletManager
        self.solanaClient = solanaClient
        self.confirmationHandler = confirmationHandler
    }

    @Generable
    struct Arguments {
        @Guide(description: "Recipient Solana base58 address (must be 32-byte base58, not a domain)")
        var recipient: String
        @Guide(description: "Amount to send in token units (e.g. 0.5 for 0.5 SOL)")
        var amount: Double
        @Guide(description: "Optional SPL token mint address. Omit to send native SOL.")
        var tokenMint: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard walletManager.isConnected else {
            return "Wallet not connected."
        }

        guard Base58.isValidAddress(arguments.recipient) else {
            return "Invalid recipient address '\(arguments.recipient)'. Please provide a valid Solana base58 address (44 characters, no domains)."
        }

        guard arguments.amount > 0 else {
            return "Amount must be greater than 0."
        }

        let tokenSymbol = arguments.tokenMint == nil ? "SOL" : "tokens"
        let preview = TransactionPreview(
            action: "send",
            amount: arguments.amount,
            tokenSymbol: tokenSymbol,
            recipient: arguments.recipient,
            estimatedFee: 0.000005,
            summary: "⚠️ DEVNET — Send \(arguments.amount) \(tokenSymbol) to \(arguments.recipient.prefix(8))…\(arguments.recipient.suffix(4))"
        )

        // Show native confirmation card and suspend until user responds.
        let confirmed = await confirmationHandler.requestConfirmation(preview)
        guard confirmed else {
            return "Transaction cancelled by user."
        }

        // Build and sign with a fresh blockhash (fetched AFTER confirmation so it doesn't expire).
        do {
            let lamports = UInt64(arguments.amount * 1_000_000_000)
            let keypair = try walletManager.keypairForSigning()
            let blockhash = try await solanaClient.getLatestBlockhash()

            let txData = try TransactionBuilder.buildSOLTransfer(
                from: keypair,
                to: arguments.recipient,
                lamports: lamports,
                recentBlockhash: blockhash
            )

            let signature = try await solanaClient.sendTransaction(serialized: txData)

            guard signature.count >= 80, Base58.decode(signature) != nil else {
                return "⚠️ DEVNET: sendTransaction returned an unexpected response. The transaction may not have been submitted. Check the explorer manually."
            }

            return """
            ✅ DEVNET: Transaction sent!
            Signature: \(signature)
            Explorer: \(SolanaNetwork.explorerURL(signature: signature).absoluteString)
            """
        } catch {
            return "Transaction failed: \(error.localizedDescription)"
        }
    }
}

