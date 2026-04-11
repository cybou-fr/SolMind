import Foundation

// MARK: - Token Price Service
// Primary: Jupiter Price API v2 (price returned as String)
// Fallback: CoinGecko free API

actor PriceService {
    static let shared = PriceService()

    private var cache: [String: (price: Double, fetchedAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 30

    // Known symbol-to-mint mappings for Jupiter Price API (mainnet mints for price lookup)
    private let symbolToMint: [String: String] = [
        "SOL":  "So11111111111111111111111111111111111111112",
        "USDC": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "USDT": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "BTC":  "9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E",
        "ETH":  "2FPyTwcZLUglTvA6naznkuoARgABCnpQSbPQgBBeNdnd"
    ]

    // CoinGecko coin IDs for fallback lookups
    private let symbolToCoinGeckoId: [String: String] = [
        "SOL":  "solana",
        "USDC": "usd-coin",
        "USDT": "tether",
        "BTC":  "bitcoin",
        "ETH":  "ethereum"
    ]

    // MARK: - Public API

    /// Read from in-memory cache without a network call (non-throwing).
    /// Returns nil if the symbol has never been fetched or the cached value has expired.
    /// Prefer this in context-block builders that should not trigger a network fetch.
    func cachedPrice(for symbol: String) async -> Double? {
        let key = symbol.uppercased()
        guard let cached = cache[key],
              Date().timeIntervalSince(cached.fetchedAt) < cacheTTL else { return nil }
        return cached.price
    }

    func getPrice(symbol: String) async throws -> Double? {
        let key = symbol.uppercased()

        // Return cached value if still fresh
        if let cached = cache[key], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.price
        }

        // Resolve symbol → mint address for Jupiter (or use raw input if it's already a mint)
        let mint = symbolToMint[key] ?? key

        // 1. Try Jupiter Price API v2
        if let price = try? await fetchJupiterPrice(mint: mint) {
            cache[key] = (price, Date())
            return price
        }

        // 2. Fallback: CoinGecko (for well-known symbols only)
        if let geckoId = symbolToCoinGeckoId[key],
           let price = try? await fetchCoinGeckoPrice(geckoId: geckoId) {
            cache[key] = (price, Date())
            return price
        }

        return nil
    }

    // MARK: - Jupiter Price API v2

    private func fetchJupiterPrice(mint: String) async throws -> Double? {
        guard let url = URL(string: "https://api.jup.ag/price/v2?ids=\(mint)") else { return nil }

        struct PriceResponse: Decodable {
            let data: [String: PriceData]
        }
        // Jupiter v2 returns `price` as a JSON String, not a number.
        struct PriceData: Decodable {
            let price: String
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PriceResponse.self, from: data)

        guard let priceData = response.data[mint], let price = Double(priceData.price) else {
            return nil
        }
        return price
    }

    // MARK: - CoinGecko Fallback

    private func fetchCoinGeckoPrice(geckoId: String) async throws -> Double? {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(geckoId)&vs_currencies=usd") else { return nil }

        // Response: { "solana": { "usd": 135.12 } }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        return json[geckoId]?["usd"]
    }
}
