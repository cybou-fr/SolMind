import FoundationModels
import Foundation

// MARK: - Send Tokens Tool

struct SendTool: Tool {
    let name = "sendTokens"
    let description = "Send SOL or SPL tokens to a recipient address. Returns a transaction preview for user confirmation BEFORE executing. Always call this tool when the user wants to send/transfer tokens."

    @MainActor private let walletManager: WalletManager
    private let solanaClient: SolanaClient

    init(walletManager: WalletManager, solanaClient: SolanaClient) {
        self.walletManager = walletManager
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "Recipient Solana base58 address")
        var recipient: String
        @Guide(description: "Amount to send in token units (e.g. 0.5 for 0.5 SOL)")
        var amount: Double
        @Guide(description: "Optional SPL token mint address. Omit to send SOL.")
        var tokenMint: String?
        @Guide(description: "Set to true only after user has confirmed the transaction preview")
        var confirmed: Bool?
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        guard walletManager.isConnected else {
            return "Wallet not connected."
        }

        guard Base58.isValidAddress(arguments.recipient) else {
            return "Invalid recipient address: '\(arguments.recipient)'. Please provide a valid Solana base58 address."
        }

        guard arguments.amount > 0 else {
            return "Amount must be greater than 0."
        }

        if arguments.confirmed != true {
            let fee = 0.000005
            let preview = """
            ⚠️ DEVNET TRANSACTION PREVIEW:
            Action: Send
            Amount: \(arguments.amount) \(arguments.tokenMint != nil ? "tokens (mint: \(arguments.tokenMint!))" : "SOL")
            To: \(arguments.recipient)
            Estimated fee: \(fee) SOL
            
            Reply with confirmed: true to execute, or decline.
            """
            return preview
        }

        // Execute after confirmation
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
        return """
        ✅ DEVNET: Transaction sent!
        Signature: \(signature)
        Explorer: \(SolanaNetwork.explorerURL(signature: signature).absoluteString)
        """
    }
}
