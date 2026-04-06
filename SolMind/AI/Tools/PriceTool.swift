import FoundationModels
import Foundation

// MARK: - Price Tool

struct PriceTool: Tool {
    let name = "getPrice"
    let description = "Get the current USD price of a Solana token by its symbol or mint address. Examples: SOL, USDC, BTC."

    private let priceService: PriceService

    init(priceService: PriceService = PriceService()) {
        self.priceService = priceService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Token symbol (e.g. SOL, USDC, BTC) or mint address")
        var tokenSymbol: String
    }

    func call(arguments: Arguments) async throws -> String {
        let price = try await priceService.getPrice(symbol: arguments.tokenSymbol)
        if let p = price {
            return "Current price of \(arguments.tokenSymbol.uppercased()): $\(String(format: "%.4f", p)) USD"
        }
        return "Could not fetch price for \(arguments.tokenSymbol). Try with a different symbol."
    }
}
