import FoundationModels
import Foundation

// MARK: - Create SPL Token Tool

struct CreateTokenTool: Tool {
    let name = "createToken"
    let description = """
    Create a new SPL token (fungible token) on Solana devnet. Generates a fresh mint address, \
    initialises the mint, creates an associated token account, and mints the initial supply to the \
    connected wallet. Requires ~0.005 SOL for rent. Shows a native confirmation card before executing.
    """

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
        @Guide(description: "Human-readable token name (e.g. 'SolMind Token')")
        var tokenName: String

        @Guide(description: "Token ticker symbol, max 10 chars (e.g. 'SMND')")
        var symbol: String

        @Guide(description: "Decimal places for the token (0 = whole units, 6 = micro units like USDC). Default: 6.")
        var decimals: Int?

        @Guide(description: "Total initial supply to mint into the connected wallet (e.g. 1000000 for 1 M tokens). Default: 1 000 000.")
        var totalSupply: Double?
    }

    func call(arguments: Arguments) async throws -> String {
        guard walletManager.isConnected else {
            return "Wallet not connected."
        }

        let decimals = UInt8(max(0, min(9, arguments.decimals ?? 6)))
        let supply = arguments.totalSupply ?? 1_000_000
        let multiplier = pow(10.0, Double(decimals))
        let rawSupply = UInt64(supply * multiplier)

        let preview = TransactionPreview(
            action: "create",
            amount: supply,
            tokenSymbol: arguments.symbol.uppercased(),
            recipient: "",
            estimatedFee: 0.005,
            summary: "Create SPL token '\(arguments.tokenName)' (\(arguments.symbol.uppercased())) with \(formatSupply(supply)) total supply, \(decimals) decimals"
        )

        guard await confirmationHandler.requestConfirmation(preview) else {
            return "Token creation cancelled."
        }

        await MainActor.run { ToastManager.shared.info("Creating token mint…") }

        let payer: Keypair
        do { payer = try walletManager.keypairForSigning() } catch {
            return "Wallet signing unavailable: \(error.localizedDescription)"
        }

        // Generate ephemeral keypair for the new mint address
        let mintKeypair = Keypair.generate()

        // --- Transaction 1: createAccount + initializeMint2 ---
        let blockhash1 = try await solanaClient.getLatestBlockhash()
        let createMintTx: Data
        do {
            createMintTx = try TransactionBuilder.buildCreateMint(
                payer: payer,
                mintKeypair: mintKeypair,
                decimals: decimals,
                recentBlockhash: blockhash1
            )
        } catch {
            return "Failed to build mint transaction: \(error.localizedDescription)"
        }

        let createSig: String
        do {
            createSig = try await solanaClient.sendTransaction(serialized: createMintTx)
        } catch {
            return "Failed to create mint account: \(error.localizedDescription). Make sure you have enough SOL (~0.005) for rent."
        }

        guard createSig.count >= 80, Base58.decode(createSig) != nil else {
            return "Mint creation returned an invalid signature: \(createSig)"
        }

        // Allow the transaction to land before the next one references the mint account
        await MainActor.run { ToastManager.shared.info("Waiting for mint to confirm…") }
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // --- Transaction 2: createATA (idempotent) + mintTo ---
        let blockhash2 = try await solanaClient.getLatestBlockhash()
        let mintTx: Data
        do {
            mintTx = try TransactionBuilder.buildMintTokens(
                payer: payer,
                mint: mintKeypair.publicKeyBytes,
                amount: rawSupply,
                recentBlockhash: blockhash2
            )
        } catch {
            return "Mint created, but failed to build mint-tokens transaction: \(error.localizedDescription). Mint: \(mintKeypair.publicKeyBase58)"
        }

        let mintSig: String
        do {
            mintSig = try await solanaClient.sendTransaction(serialized: mintTx)
        } catch {
            return "Mint account created, but failed to mint tokens: \(error.localizedDescription). Mint: \(mintKeypair.publicKeyBase58)"
        }

        guard mintSig.count >= 80, Base58.decode(mintSig) != nil else {
            return "Mint-tokens transaction returned an invalid signature: \(mintSig). Mint: \(mintKeypair.publicKeyBase58)"
        }

        let mintAddress = mintKeypair.publicKeyBase58
        await MainActor.run { ToastManager.shared.success("✓ Token '\(arguments.symbol.uppercased())' created!") }
        return """
        ⚠️ DEVNET: Token '\(arguments.tokenName)' created successfully!

        Symbol: \(arguments.symbol.uppercased())
        Decimals: \(decimals)
        Total Supply: \(formatSupply(supply)) \(arguments.symbol.uppercased())
        Mint Address: \(mintAddress)

        Transactions:
        • Create mint: \(SolanaNetwork.explorerURL(signature: createSig).absoluteString)
        • Mint tokens: \(SolanaNetwork.explorerURL(signature: mintSig).absoluteString)

        View on Explorer: \(SolanaNetwork.explorerURL(address: mintAddress).absoluteString)
        """
    }

    private func formatSupply(_ n: Double) -> String {
        if n >= 1_000_000_000 { return "\(Int(n / 1_000_000_000))B" }
        if n >= 1_000_000     { return "\(Int(n / 1_000_000))M" }
        if n >= 1_000         { return "\(Int(n / 1_000))K" }
        return "\(Int(n))"
    }
}
