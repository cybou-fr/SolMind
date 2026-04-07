import Foundation

// MARK: - Token Price Service (Jupiter Price API)

actor PriceService {
    static let shared = PriceService()

    private var cache: [String: (price: Double, fetchedAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 30

    // Known symbol-to-mint mappings for Jupiter Price API
    private let symbolToMint: [String: String] = [
        "SOL": "So11111111111111111111111111111111111111112",
        "USDC": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "USDT": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "BTC": "9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E",
        "ETH": "2FPyTwcZLUglTvA6naznkuoARgABCnpQSbPQgBBeNdnd"
    ]

    func getPrice(symbol: String) async throws -> Double? {
        let key = symbol.uppercased()

        // Check cache
        if let cached = cache[key], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.price
        }

        let mint = symbolToMint[key] ?? key
        guard let url = URL(string: "https://api.jup.ag/price/v2?ids=\(mint)") else { return nil }

        struct PriceResponse: Decodable {
            let data: [String: PriceData]
        }
        struct PriceData: Decodable {
            let price: Double
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PriceResponse.self, from: data)

        if let priceData = response.data[mint] {
            cache[key] = (priceData.price, Date())
            return priceData.price
        }
        return nil
    }
}
