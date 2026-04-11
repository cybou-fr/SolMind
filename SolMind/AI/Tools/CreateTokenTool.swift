import FoundationModels
import Foundation

// MARK: - Create SPL Token Tool

struct CreateTokenTool: Tool {
    let name = "createToken"
    let description = "Create a new SPL fungible token on devnet with mint address and initial supply. Requires ~0.005 SOL. Requires confirmation."

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
        @Guide(description: "Token name")
        var tokenName: String

        @Guide(description: "Ticker symbol (max 10 chars)")
        var symbol: String

        @Guide(description: "Decimal places (default 6)")
        var decimals: Int?

        @Guide(description: "Initial supply (default 1000000)")
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
            return "⚠️ TERMINAL: Wallet signing unavailable — \(error.localizedDescription). Do NOT retry automatically."
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
            return "⚠️ TERMINAL: Could not build mint transaction — \(error.localizedDescription). Do NOT retry automatically."
        }

        let createSig: String
        do {
            createSig = try await solanaClient.sendTransaction(serialized: createMintTx)
        } catch {
            return "⚠️ TERMINAL: Token creation failed before any on-chain state was written. Reason: \(error.localizedDescription). The user needs ~0.005 SOL for rent. Do NOT retry automatically."
        }

        guard createSig.count >= 80, Base58.decode(createSig) != nil else {
            return "⚠️ TERMINAL: Mint creation returned an invalid signature — the transaction may not have been sent. Signature: \(createSig). Do NOT retry automatically."
        }

        // Wait for the mint account to be confirmed before referencing it in the next tx.
        await MainActor.run { ToastManager.shared.info("Confirming mint creation…") }
        _ = try? await solanaClient.confirmTransaction(signature: createSig, maxAttempts: 20)

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
            return "⚠️ PARTIAL: Mint account was created (tx: \(createSig.prefix(12))…) but the token-mint transaction could not be built: \(error.localizedDescription). Do NOT retry the whole createToken flow — the mint address already exists (visible in Portfolio tab)."
        }

        let mintSig: String
        do {
            mintSig = try await solanaClient.sendTransaction(serialized: mintTx)
        } catch {
            return "⚠️ PARTIAL: Mint account was created (tx: \(createSig.prefix(12))…) but minting tokens failed: \(error.localizedDescription). Do NOT call createToken again — inform the user the mint exists but has no supply yet (mint visible in Portfolio tab)."
        }

        guard mintSig.count >= 80, Base58.decode(mintSig) != nil else {
            return "⚠️ PARTIAL: Mint-tokens transaction returned an invalid signature. Do NOT retry automatically."
        }

        let mintAddress = mintKeypair.publicKeyBase58
        // Abbreviate for tool result — full base58 addresses trigger language detection.
        let mintShort = "\(mintAddress.prefix(8))…\(mintAddress.suffix(4))"

        // Persist metadata so Portfolio shows name/symbol instead of raw address.
        AppSettings.shared.registerToken(
            mint: mintAddress,
            symbol: arguments.symbol.uppercased(),
            name: arguments.tokenName
        )

        await MainActor.run { ToastManager.shared.success("✓ Token '\(arguments.symbol.uppercased())' created!") }
        return """
        ✅ DEVNET: Token created successfully!
        Name: \(arguments.tokenName) | Symbol: \(arguments.symbol.uppercased()) | Decimals: \(decimals) | Supply: \(formatSupply(supply))
        Mint: \(mintShort) (full address in Portfolio tab)
        TX(create): \(createSig.prefix(12))… TX(mint): \(mintSig.prefix(12))…
        """
    }

    private func formatSupply(_ n: Double) -> String {
        if n >= 1_000_000_000 { return "\(Int(n / 1_000_000_000))B" }
        if n >= 1_000_000     { return "\(Int(n / 1_000_000))M" }
        if n >= 1_000         { return "\(Int(n / 1_000))K" }
        return "\(Int(n))"
    }
}
