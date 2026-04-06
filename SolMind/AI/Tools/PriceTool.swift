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

    struct Input: Codable {
        var tokenSymbol: String
    }

    func call(input: Input) async throws -> ToolOutput {
        let price = try await priceService.getPrice(symbol: input.tokenSymbol)
        if let p = price {
            return ToolOutput("Current price of \(input.tokenSymbol.uppercased()): $\(String(format: "%.4f", p)) USD")
        }
        return ToolOutput("Could not fetch price for \(input.tokenSymbol). Try with a different symbol.")
    }
}
