import FoundationModels
import Foundation

// MARK: - On-Ramp Tool (MoonPay Sandbox)

struct OnRampTool: Tool {
    let name = "buyWithFiat"
    let description = "Open the MoonPay widget to buy SOL with fiat currency (USD, EUR, etc.) via credit card. This is a sandbox demo — use test card 4242 4242 4242 4242."

    @MainActor private let walletManager: WalletManager

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }

    @Generable
    struct Arguments {
        @Guide(description: "Amount in fiat currency (e.g. 50 for $50)")
        var amount: Double?
        @Guide(description: "Fiat currency code (e.g. usd, eur). Defaults to usd.")
        var currency: String?
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return ToolOutput("Wallet not connected.")
        }

        // Build MoonPay sandbox URL
        var components = URLComponents(string: "https://buy-sandbox.moonpay.com")!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: Secrets.moonpayAPIKey),
            URLQueryItem(name: "currencyCode", value: "sol"),
            URLQueryItem(name: "walletAddress", value: publicKey),
            URLQueryItem(name: "baseCurrencyCode", value: arguments.currency?.lowercased() ?? "usd"),
            URLQueryItem(name: "baseCurrencyAmount", value: String(arguments.amount ?? 50)),
            URLQueryItem(name: "colorCode", value: "%239945FF")
        ]

        guard let url = components.url else {
            return "Could not build MoonPay URL."
        }

        // Open in browser
        openURL(url)

        return """
        Opening MoonPay sandbox to buy SOL.
        Wallet: \(publicKey)
        Amount: $\(String(format: "%.0f", arguments.amount ?? 50)) \((arguments.currency ?? "USD").uppercased())
        
        ⚠️ SANDBOX MODE — Use test card: 4242 4242 4242 4242, any future expiry, any CVV.
        This is a demo — no real money will be charged.
        """
    }

    @MainActor
    private func openURL(_ url: URL) {
#if os(macOS)
        NSWorkspace.shared.open(url)
#else
        UIApplication.shared.open(url)
#endif
    }
}
