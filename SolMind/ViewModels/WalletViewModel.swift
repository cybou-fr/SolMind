import Foundation

// MARK: - Wallet ViewModel

@Observable
@MainActor
class WalletViewModel {
    var walletManager = WalletManager()
    var solBalance: Double = 0
    var solUSDValue: Double?
    var tokenBalances: [TokenBalance] = []
    var recentTransactions: [TransactionModel] = []
    var isLoading = false
    var isLoadingTransactions = false
    var setupError: String?

    /// Total portfolio value in USD (SOL + tokens). Nil until prices are loaded.
    var totalPortfolioUSD: Double? {
        guard let solUSD = solUSDValue else { return nil }
        let tokenUSD = tokenBalances.compactMap(\.usdValue).reduce(0, +)
        return solUSD + tokenUSD
    }

    private let solanaClient = SolanaClient()
    private let priceService = PriceService.shared

    var isWalletReady: Bool { walletManager.isConnected }
    var publicKey: String? { walletManager.publicKey }
    var displayAddress: String { walletManager.displayAddress }

    /// All wallet addresses stored on this device, including the active one.
    var allAddresses: [String] { walletManager.allAddresses }

    /// Set to true when the last SOL balance fetch failed (network/RPC error).
    /// Views can use this to show a stale-data indicator.
    var lastRefreshFailed = false

    // MARK: - Setup

    func setup() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try walletManager.loadOrCreateWallet()
            await refreshBalance()
        } catch {
            setupError = error.localizedDescription
        }
    }

    // MARK: - Multi-wallet

    /// Generate a new keypair, persist it, and activate it. Returns the new address.
    @discardableResult
    func generateNewWallet() async throws -> String {
        let address = try walletManager.createAndActivateWallet()
        solBalance = 0
        tokenBalances = []
        return address
    }

    /// Switch the active wallet to `address`.
    func switchWallet(to address: String) async throws {
        try walletManager.switchWallet(to: address)
        solBalance = 0
        tokenBalances = []
        await refreshBalance()
    }

    /// Delete a wallet. Switches to the next one automatically if it was active.
    func deleteWallet(address: String) async throws {
        try walletManager.deleteWallet(address: address)
        await refreshBalance()
    }

    /// Import a wallet from a 64-byte base58 private key, activate it, and refresh balances.
    @discardableResult
    func importWallet(privateKeyBase58: String) async throws -> String {
        let address = try walletManager.importAndActivateWallet(privateKeyBase58: privateKeyBase58)
        solBalance = 0
        tokenBalances = []
        await refreshBalance()
        return address
    }

    // MARK: - Balance

    func refreshBalance() async {
        guard let pk = walletManager.publicKey else { return }

        // SOL balance, token accounts, and SOL price fetched concurrently.
        // Each result is applied independently so a token error never prevents
        // the SOL balance from updating.
        async let solFetch = solanaClient.getSOLBalance(publicKey: pk)
        async let tokenFetch = solanaClient.getTokenAccounts(owner: pk)
        async let priceFetch: Double? = try? await priceService.getPrice(symbol: "SOL")

        if let balance = try? await solFetch {
            solBalance = balance
            let price = await priceFetch
            solUSDValue = price.map { balance * $0 }
            lastRefreshFailed = false
        } else {
            lastRefreshFailed = true
        }

        if let tokenAccounts = try? await tokenFetch {
            var tokens = tokenAccounts.map { account in
                TokenBalance(
                    mint: account.mint,
                    symbol: knownSymbol(for: account.mint),
                    name: knownName(for: account.mint),
                    decimals: account.decimals,
                    rawAmount: account.rawAmount
                )
            }
            // Fetch token USD values concurrently
            await withTaskGroup(of: (Int, Double?).self) { group in
                for (index, token) in tokens.enumerated() {
                    let symbol = token.symbol
                    let uiAmount = token.uiAmount
                    group.addTask {
                        let price = try? await self.priceService.getPrice(symbol: symbol)
                        let usdValue: Double? = price.map { uiAmount * $0 }
                        return (index, usdValue)
                    }
                }
                for await (index, usdValue) in group {
                    tokens[index].usdValue = usdValue
                }
            }
            tokenBalances = tokens
        }
    }

    // MARK: - Transaction History

    func refreshTransactionHistory() async {
        guard let pk = walletManager.publicKey else { return }
        isLoadingTransactions = true
        defer { isLoadingTransactions = false }
        do {
            let sigs = try await solanaClient.getSignaturesForAddress(publicKey: pk, limit: 10)
            recentTransactions = sigs.map { sig in
                TransactionModel(
                    signature: sig.signature,
                    slot: sig.slot,
                    blockTime: sig.blockTime,
                    fee: 0,
                    isSuccess: sig.err == nil,
                    memo: sig.memo
                )
            }
        } catch {
            // Non-fatal — keep existing list
        }
    }

    // MARK: - Faucet

    func requestAirdrop(solAmount: Double = 1.0) async throws -> String {
        guard let pk = walletManager.publicKey else { throw WalletError.notConnected }
        let lamports = UInt64(min(solAmount, 2.0) * 1_000_000_000)

        // Try three distinct providers — same order as FaucetTool.
        let endpoints: [URL] = [
            URL(string: "https://api.devnet.solana.com")!,
            URL(string: "https://devnet.helius-rpc.com/?api-key=\(AppSettings.shared.effectiveHeliusAPIKey)")!,
            URL(string: "https://rpc.ankr.com/solana_devnet")!
        ]
        for url in endpoints {
            let client = SolanaClient(rpcURL: url)
            if let sig = try? await client.requestAirdrop(to: pk, lamports: lamports) {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await refreshBalance()
                return sig
            }
        }
        throw RPCError(code: -1, message: "All devnet faucet providers are rate-limited. Try again later or visit faucet.solana.com.")
    }

    // MARK: - Known Token Metadata (devnet)

    private func knownSymbol(for mint: String) -> String {
        knownTokens[mint]?.symbol ?? mint.prefix(6).description
    }

    private func knownName(for mint: String) -> String {
        knownTokens[mint]?.name ?? "Token \(mint.prefix(6))…"
    }

    private let knownTokens: [String: (symbol: String, name: String)] = [
        // Mainnet / standard mints (Jupiter price API uses these)
        "So11111111111111111111111111111111111111112": ("SOL", "Wrapped SOL"),
        "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": ("USDC", "USD Coin"),
        "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB": ("USDT", "Tether USD"),
        // Devnet-specific mints
        "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU": ("USDC", "USD Coin (devnet)")
    ]
}

