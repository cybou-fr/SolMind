import Foundation

// MARK: - Wallet ViewModel

@Observable
@MainActor
class WalletViewModel {
    var walletManager = WalletManager()
    var solBalance: Double = 0
    var tokenBalances: [TokenBalance] = []
    var isLoading = false
    var setupError: String?

    private let solanaClient = SolanaClient()

    var isWalletReady: Bool { walletManager.isConnected }
    var publicKey: String? { walletManager.publicKey }
    var displayAddress: String { walletManager.displayAddress }

    /// All wallet addresses stored on this device, including the active one.
    var allAddresses: [String] { walletManager.allAddresses }

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

    // MARK: - Balance

    func refreshBalance() async {
        guard let pk = walletManager.publicKey else { return }
        do {
            solBalance = try await solanaClient.getSOLBalance(publicKey: pk)
            let tokenAccounts = try await solanaClient.getTokenAccounts(owner: pk)
            tokenBalances = tokenAccounts.map { account in
                TokenBalance(
                    mint: account.mint,
                    symbol: knownSymbol(for: account.mint),
                    name: knownName(for: account.mint),
                    decimals: account.decimals,
                    rawAmount: account.rawAmount
                )
            }
        } catch {
            // Balance errors are non-fatal — keep existing values
        }
    }

    // MARK: - Faucet

    func requestAirdrop(solAmount: Double = 1.0) async throws -> String {
        guard let pk = walletManager.publicKey else { throw WalletError.notConnected }
        let lamports = UInt64(min(solAmount, 2.0) * 1_000_000_000)
        let signature = try await solanaClient.requestAirdrop(to: pk, lamports: lamports)
        // Refresh balance after short delay
        try await Task.sleep(nanoseconds: 3_000_000_000)
        await refreshBalance()
        return signature
    }

    // MARK: - Known Token Metadata (devnet)

    private func knownSymbol(for mint: String) -> String {
        knownTokens[mint]?.symbol ?? mint.prefix(6).description
    }

    private func knownName(for mint: String) -> String {
        knownTokens[mint]?.name ?? "Unknown Token"
    }

    private let knownTokens: [String: (symbol: String, name: String)] = [
        "So11111111111111111111111111111111111111112": ("SOL", "Wrapped SOL"),
        "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": ("USDC", "USD Coin"),
        "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB": ("USDT", "Tether USD")
    ]
}

