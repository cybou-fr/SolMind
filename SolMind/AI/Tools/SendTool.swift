import FoundationModels
import Foundation

// MARK: - Send Tokens Tool

struct SendTool: Tool {
    let name = "sendTokens"
    let description = "Send SOL or SPL tokens to a recipient. Requires confirmation."

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
        @Guide(description: "Recipient base58 address")
        var recipient: String
        @Guide(description: "Amount in token units")
        var amount: Double
        @Guide(description: "SPL mint address (nil = SOL)")
        var tokenMint: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard walletManager.isConnected else {
            return "Wallet not connected."
        }

        guard Base58.isValidAddress(arguments.recipient) else {
            return "Invalid recipient address '\(arguments.recipient)'. Please provide a valid Solana base58 address."
        }

        guard arguments.amount > 0 else {
            return "Amount must be greater than 0."
        }

        // Route to SOL or SPL transfer
        if let tokenMint = arguments.tokenMint, !tokenMint.isEmpty {
            return try await sendSPLTokens(recipient: arguments.recipient, amount: arguments.amount, mintAddress: tokenMint)
        } else {
            return try await sendSOL(recipient: arguments.recipient, amount: arguments.amount)
        }
    }

    // MARK: - SOL Transfer

    private func sendSOL(recipient: String, amount: Double) async throws -> String {
        let preview = TransactionPreview(
            action: "send",
            amount: amount,
            tokenSymbol: "SOL",
            recipient: recipient,
            estimatedFee: 0.000005,
            summary: "⚠️ DEVNET — Send \(amount) SOL to \(recipient)"
        )

        let confirmed = await confirmationHandler.requestConfirmation(preview)
        guard confirmed else { return "Transaction cancelled by user." }

        await MainActor.run { ToastManager.shared.info("Sending transaction…") }

        do {
            let lamports = UInt64(amount * 1_000_000_000)
            let keypair = try walletManager.keypairForSigning()
            let blockhash = try await solanaClient.getLatestBlockhash()

            let txData = try TransactionBuilder.buildSOLTransfer(
                from: keypair,
                to: recipient,
                lamports: lamports,
                recentBlockhash: blockhash
            )

            let signature = try await solanaClient.sendTransaction(serialized: txData)

            guard signature.count >= 80, Base58.decode(signature) != nil else {
                await MainActor.run { ToastManager.shared.warning("Transaction sent but response was unexpected — verify on Explorer.") }
                return "⚠️ DEVNET: sendTransaction returned an unexpected response. Check the explorer manually."
            }

            await MainActor.run { ToastManager.shared.success("✓ \(amount) SOL sent!") }
            return "✅ DEVNET: Transaction sent! \(amount) SOL → \(recipient). TX: \(signature.prefix(12))…"
        } catch {
            await MainActor.run { ToastManager.shared.error("Send failed: \(error.localizedDescription)") }
            return "⚠️ TERMINAL: SOL transfer failed — \(error.localizedDescription). Do NOT retry automatically."
        }
    }

    // MARK: - SPL Token Transfer

    private func sendSPLTokens(recipient: String, amount: Double, mintAddress: String) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        // Fetch sender's token accounts to get the correct decimals
        let tokenAccounts = try await solanaClient.getTokenAccounts(owner: publicKey)
        let matchingAccount = tokenAccounts.first(where: { $0.mint == mintAddress })

        guard let tokenAccount = matchingAccount else {
            return """
            No token account found for mint \(mintAddress) in this wallet. \
            Make sure you hold this token before sending. \
            Your current token accounts: \(tokenAccounts.map { $0.mint }.joined(separator: ", "))
            """
        }

        guard tokenAccount.uiAmount >= amount else {
            return "Insufficient token balance. You have \(String(format: "%.4f", tokenAccount.uiAmount)) tokens, but tried to send \(amount)."
        }

        // Convert UI amount to raw units using the token's actual decimals
        let rawAmount = UInt64(amount * pow(10.0, Double(tokenAccount.decimals)))

        let preview = TransactionPreview(
            action: "send",
            amount: amount,
            tokenSymbol: "tokens (mint: \(mintAddress))",
            recipient: recipient,
            estimatedFee: 0.000005,
            summary: "⚠️ DEVNET — Send \(amount) tokens [\(mintAddress)] to \(recipient)"
        )

        let confirmed = await confirmationHandler.requestConfirmation(preview)
        guard confirmed else { return "Transaction cancelled by user." }

        await MainActor.run { ToastManager.shared.info("Sending token transfer…") }

        do {
            let keypair = try walletManager.keypairForSigning()
            let blockhash = try await solanaClient.getLatestBlockhash()

            let txData = try TransactionBuilder.buildSPLTransfer(
                from: keypair,
                to: recipient,
                mintBase58: mintAddress,
                amount: rawAmount,
                recentBlockhash: blockhash
            )

            let signature = try await solanaClient.sendTransaction(serialized: txData)

            guard signature.count >= 80, Base58.decode(signature) != nil else {
                await MainActor.run { ToastManager.shared.warning("Transfer sent but response was unexpected — verify on Explorer.") }
                return "⚠️ DEVNET: sendTransaction returned an unexpected response. Check the explorer manually."
            }

            await MainActor.run { ToastManager.shared.success("✓ \(amount) tokens sent!") }
            return "✅ DEVNET: Token transfer sent! \(amount) tokens → \(recipient). TX: \(signature.prefix(12))…"
        } catch {
            await MainActor.run { ToastManager.shared.error("Transfer failed: \(error.localizedDescription)") }
            return "⚠️ TERMINAL: SPL transfer failed — \(error.localizedDescription). Do NOT retry automatically."
        }
    }
}
