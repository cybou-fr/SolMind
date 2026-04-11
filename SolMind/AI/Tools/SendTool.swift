import FoundationModels
import Foundation

// MARK: - Send Tokens Tool

struct SendTool: Tool {
    let name = "sendTokens"
    let description = """
    Send SOL or SPL tokens to a recipient address. \
    For SOL pass token='SOL' (or leave nil). \
    For any other token pass the symbol (e.g. 'USDC', 'USDT', 'BONK') or the raw mint address — \
    the tool resolves symbols automatically. Requires confirmation.
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
        @Guide(description: "Recipient base58 address")
        var recipient: String

        @Guide(description: "Amount in human-readable token units (e.g. 1.5)")
        var amount: Double

        @Guide(description: """
        Token to send. Use 'SOL' or nil for native SOL. \
        For SPL tokens use the symbol: 'USDC', 'USDT', 'EURC', 'BONK', 'JUP', 'RAY', 'mSOL', etc. \
        You may also pass a raw base58 mint address directly.
        """)
        var token: String?
    }

    // MARK: - Symbol → Devnet Mint resolver
    // Devnet: USDC has a dedicated devnet mint (Circle). Other major tokens share mainnet addresses
    // but typically have no on-chain supply on devnet — the wallet holds whatever was acquired via faucet/swap.

    private static let symbolToMint: [String: String] = [
        "USDC":  "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",    // Circle devnet USDC
        "USDT":  "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "EURC":  "HzwqbKZw8HxMN6bF2yFZNrht3c2iXXzpKcFu7uBEDKtr",
        "ETH":   "7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs",
        "MSOL":  "mSoLzYCxHdYgdzU16g5QSh3i5K3z3kZMofdkxtBDnFt",
        "BONK":  "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263",
        "JUP":   "JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN",
        "RAY":   "4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R",
        "PYTH":  "HZ1JovNiVvGrG2fvSXCZPdVZHqAHu7aXXSLQ6gEzDhSH",
        "WIF":   "EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm",
        "WSOL":  "So11111111111111111111111111111111111111112",
    ]

    /// Abbreviates a base58 address for safe injection into FM tool results.
    /// Full 32–44 char base58 strings trigger the FM language classifier.
    private func abbrev(_ address: String) -> String {
        PromptSanitizer.abbreviateBase58(address)
    }

    /// Returns nil for SOL (native), or a mint address for SPL tokens.
    /// Accepts symbol strings ("USDC"), mint addresses (44-char base58), or nil/"SOL".
    private func resolveMint(_ token: String?, walletTokens: [TokenAccount]) -> String?? {
        // nil or explicit "SOL" → native SOL
        guard let raw = token?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return .some(nil) }
        let upper = raw.uppercased()
        if upper == "SOL" { return .some(nil) }

        // Direct mint address
        if raw.count >= 32 && Base58.isValidAddress(raw) { return .some(raw) }

        // Known symbol table
        if let mint = Self.symbolToMint[upper] { return .some(mint) }

        // Fall back to whatever the wallet actually holds (user-created tokens)
        if let match = walletTokens.first(where: {
            AppSettings.shared.tokenMetadata(for: $0.mint)?.symbol.uppercased() == upper
        }) {
            return .some(match.mint)
        }

        // Unknown token — return sentinel to signal error
        return nil
    }

    func call(arguments: Arguments) async throws -> String {
        guard walletManager.isConnected, let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        // Resolve [addr0] / [addr1] tags → full base58 addresses.
        // AddressRegistry is populated by ChatViewModel before every FM inference call
        // so that raw addresses never enter the FM prompt (which triggers Croatian detection).
        let resolvedRecipient = await AddressRegistry.shared.resolve(arguments.recipient) ?? arguments.recipient

        guard Base58.isValidAddress(resolvedRecipient) else {
            if arguments.recipient.hasPrefix("[addr") {
                return "I wasn't able to look up the recipient address from your message. Please use the QR scanner or retype: \"send X SOL to <address>\"."
            }
            return "Invalid recipient address '\(abbrev(arguments.recipient))'. Provide a valid Solana base58 address."
        }

        guard arguments.amount > 0 else {
            return "Amount must be greater than 0."
        }

        // Fetch token accounts once — used for both resolution and balance check
        let walletTokens = (try? await solanaClient.getTokenAccounts(owner: publicKey)) ?? []

        // Resolve token argument
        guard let resolved = resolveMint(arguments.token, walletTokens: walletTokens) else {
            let knownSymbols = Self.symbolToMint.keys.sorted().joined(separator: ", ")
            return "Unknown token '\(arguments.token ?? "")'. Supported symbols: \(knownSymbols). Or pass the raw mint address."
        }

        if let mintAddress = resolved {
            return try await sendSPLTokens(
                recipient: resolvedRecipient,
                amount: arguments.amount,
                mintAddress: mintAddress,
                symbol: arguments.token?.uppercased() ?? String(mintAddress.prefix(6)),
                walletTokens: walletTokens
            )
        } else {
            return try await sendSOL(recipient: resolvedRecipient, amount: arguments.amount)
        }
    }

    // MARK: - SOL Transfer

    private func sendSOL(recipient: String, amount: Double) async throws -> String {
        // `recipient` is already a resolved full base58 address — validated in call().
        let preview = TransactionPreview(
            action: "send",
            amount: amount,
            tokenSymbol: "SOL",
            recipient: recipient,
            estimatedFee: 0.000005,
            summary: "⚠️ DEVNET — Send \(amount) SOL to \(recipient)"
        )

        guard await confirmationHandler.requestConfirmation(preview) else {
            return "Transaction cancelled by user."
        }

        await MainActor.run { ToastManager.shared.info("Sending SOL…") }

        do {
            let lamports = UInt64(amount * 1_000_000_000)
            let keypair = try walletManager.keypairForSigning()
            let blockhash = try await solanaClient.getLatestBlockhash()
            let txData = try TransactionBuilder.buildSOLTransfer(
                from: keypair, to: recipient, lamports: lamports, recentBlockhash: blockhash)
            let signature = try await solanaClient.sendTransaction(serialized: txData)

            guard signature.count >= 80, Base58.decode(signature) != nil else {
                return "⚠️ DEVNET: Unexpected response from sendTransaction. Verify on Explorer manually."
            }

            await MainActor.run { ToastManager.shared.success("✓ \(amount) SOL sent!") }
            return "✅ DEVNET: Sent \(amount) SOL → \(abbrev(recipient)). TX: \(signature.prefix(12))…"
        } catch {
            await MainActor.run { ToastManager.shared.error("Send failed") }
            return "⚠️ TERMINAL: SOL transfer failed — \(error.localizedDescription). Do NOT retry automatically."
        }
    }

    // MARK: - SPL Token Transfer

    private func sendSPLTokens(
        recipient: String,
        amount: Double,
        mintAddress: String,
        symbol: String,
        walletTokens: [TokenAccount]
    ) async throws -> String {
        // Try to find the matching token account in the already-fetched list
        let tokenAccount = walletTokens.first(where: { $0.mint == mintAddress })

        // If not found in wallet, surface a clear error instead of a misleading SOL send
        guard let account = tokenAccount else {
            let held = walletTokens.isEmpty
                ? "none"
                : walletTokens.map { acct -> String in
                    let s = AppSettings.shared.tokenMetadata(for: acct.mint)?.symbol ?? String(acct.mint.prefix(6))
                    return "\(s) (\(String(acct.mint.prefix(8)))…)"
                }.joined(separator: ", ")
            return "⚠️ No \(symbol) token account found in this wallet. Tokens you hold: \(held). Get devnet USDC at faucet.circle.com."
        }

        guard account.uiAmount >= amount else {
            return "Insufficient \(symbol) balance. You have \(String(format: "%.4f", account.uiAmount)) but tried to send \(amount)."
        }

        let rawAmount = UInt64(amount * pow(10.0, Double(account.decimals)))

        let displaySymbol: String = {
            if let meta = AppSettings.shared.tokenMetadata(for: mintAddress) { return meta.symbol }
            return symbol
        }()

        let preview = TransactionPreview(
            action: "send",
            amount: amount,
            tokenSymbol: displaySymbol,
            recipient: recipient,
            estimatedFee: 0.000005,
            summary: "⚠️ DEVNET — Send \(amount) \(displaySymbol) to \(recipient)"
        )

        guard await confirmationHandler.requestConfirmation(preview) else {
            return "Transaction cancelled by user."
        }

        await MainActor.run { ToastManager.shared.info("Sending \(displaySymbol)…") }

        do {
            let keypair = try walletManager.keypairForSigning()
            let blockhash = try await solanaClient.getLatestBlockhash()
            let txData = try TransactionBuilder.buildSPLTransfer(
                from: keypair, to: recipient, mintBase58: mintAddress,
                amount: rawAmount, recentBlockhash: blockhash)
            let signature = try await solanaClient.sendTransaction(serialized: txData)

            guard signature.count >= 80, Base58.decode(signature) != nil else {
                return "⚠️ DEVNET: Unexpected response from sendTransaction. Verify on Explorer manually."
            }

            await MainActor.run { ToastManager.shared.success("✓ \(amount) \(displaySymbol) sent!") }
            return "✅ DEVNET: Sent \(amount) \(displaySymbol) → \(abbrev(recipient)). TX: \(signature.prefix(12))…"
        } catch {
            await MainActor.run { ToastManager.shared.error("Transfer failed") }
            return "⚠️ TERMINAL: \(displaySymbol) transfer failed — \(error.localizedDescription). Do NOT retry automatically."
        }
    }
}
