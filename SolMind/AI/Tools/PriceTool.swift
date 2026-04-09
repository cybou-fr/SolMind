import FoundationModels
import Foundation

// MARK: - Price Tool

struct PriceTool: Tool {
    let name = "getPrice"
    let description = "Get current USD price for a Solana token by symbol or mint address."

    private let priceService: PriceService

    init(priceService: PriceService = PriceService.shared) {
        self.priceService = priceService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Token symbol or mint address")
        var tokenSymbol: String
    }

    func call(arguments: Arguments) async throws -> String {
        do {
            let price = try await priceService.getPrice(symbol: arguments.tokenSymbol)
            if let p = price {
                return "Current price of \(arguments.tokenSymbol.uppercased()): $\(String(format: "%.4f", p)) USD"
            }
            return "Could not fetch price for \(arguments.tokenSymbol). Try with a different symbol."
        } catch {
            return "Price lookup failed: \(error.localizedDescription)"
        }
    }
}
