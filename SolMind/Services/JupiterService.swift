import Foundation

// MARK: - Jupiter DEX Service
// NOTE: api.jup.ag is MAINNET ONLY. Devnet has no Jupiter liquidity pools.
// Swaps via this service work on mainnet; on devnet they will return quote errors.

class JupiterService {
    // Jupiter Swap API v1 (unified)
    private static let quoteURL = URL(string: "https://api.jup.ag/swap/v1/quote")!
    private static let swapURL  = URL(string: "https://api.jup.ag/swap/v1/swap")!

    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        self.urlSession = URLSession(configuration: config)
    }

    // Well-known token mint addresses.
    // Devnet USDC: Circle's official devnet mint (faucet: https://faucet.circle.com)
    // Other tokens only exist on mainnet; Jupiter quotes for SOL↔USDC will fail on devnet.
    private static let symbolToMint: [String: String] = [
        "SOL":  "So11111111111111111111111111111111111111112",
        "WSOL": "So11111111111111111111111111111111111111112",
        "USDC": "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",  // devnet USDC (Circle)
        "USDT": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "BTC":  "9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E",
        "ETH":  "2FPyTwcZLUglTvA6naznkuoARgABCnpQSbPQgBBeNdnd"
    ]

    static func mintForSymbol(_ input: String) -> String {
        // If it looks like a mint address, use as-is
        if input.count > 20 && Base58.isValidAddress(input) { return input }
        return symbolToMint[input.uppercased()] ?? input
    }

    // MARK: - Quote

    func getQuote(inputMint: String, outputMint: String, amount: UInt64) async throws -> SwapQuote {
        var components = URLComponents(url: Self.quoteURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "inputMint",   value: inputMint),
            URLQueryItem(name: "outputMint",  value: outputMint),
            URLQueryItem(name: "amount",      value: String(amount)),
            URLQueryItem(name: "slippageBps", value: "50")
        ]

        guard let url = components.url else { throw JupiterError.invalidURL }
        let (data, _) = try await urlSession.data(from: url)
        return try JSONDecoder().decode(SwapQuote.self, from: data)
    }

    // MARK: - Swap Transaction

    func getSwapTransaction(quote: SwapQuote, userPublicKey: String) async throws -> Data {
        struct SwapRequest: Encodable {
            let quoteResponse: SwapQuote
            let userPublicKey: String
            let wrapAndUnwrapSol: Bool = true
            let dynamicComputeUnitLimit: Bool = true
            let prioritizationFeeLamports: String = "auto"
        }

        var request = URLRequest(url: Self.swapURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SwapRequest(quoteResponse: quote, userPublicKey: userPublicKey))

        let (data, _) = try await urlSession.data(for: request)

        struct SwapResponse: Decodable {
            let swapTransaction: String
        }
        let response = try JSONDecoder().decode(SwapResponse.self, from: data)

        guard let txData = Data(base64Encoded: response.swapTransaction) else {
            throw JupiterError.invalidTransaction
        }
        return txData
    }
}

// MARK: - Models

struct SwapQuote: Codable {
    let inputMint: String
    let outputMint: String
    let inAmount: String
    let outAmount: String
    // priceImpactPct: Jupiter v6 returns as String; newer APIs may return Double. Handle both.
    let priceImpactPct: String
    let routePlan: [RoutePlan]

    enum CodingKeys: String, CodingKey {
        case inputMint, outputMint, inAmount, outAmount, priceImpactPct, routePlan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        inputMint  = try c.decode(String.self, forKey: .inputMint)
        outputMint = try c.decode(String.self, forKey: .outputMint)
        inAmount   = try c.decode(String.self, forKey: .inAmount)
        outAmount  = try c.decode(String.self, forKey: .outAmount)
        routePlan  = try c.decode([RoutePlan].self, forKey: .routePlan)
        // Accept both String and Double from the API
        if let s = try? c.decode(String.self, forKey: .priceImpactPct) {
            priceImpactPct = s
        } else if let d = try? c.decode(Double.self, forKey: .priceImpactPct) {
            priceImpactPct = String(d)
        } else {
            priceImpactPct = "0"
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(inputMint,      forKey: .inputMint)
        try c.encode(outputMint,     forKey: .outputMint)
        try c.encode(inAmount,       forKey: .inAmount)
        try c.encode(outAmount,      forKey: .outAmount)
        try c.encode(priceImpactPct, forKey: .priceImpactPct)
        try c.encode(routePlan,      forKey: .routePlan)
    }
}

struct RoutePlan: Codable {
    let swapInfo: SwapInfo
}

struct SwapInfo: Codable {
    let label: String
}

enum JupiterError: LocalizedError {
    case invalidURL
    case invalidTransaction

    var errorDescription: String? {
        switch self {
        case .invalidURL:         return "Invalid Jupiter URL."
        case .invalidTransaction: return "Invalid swap transaction from Jupiter."
        }
    }
}
