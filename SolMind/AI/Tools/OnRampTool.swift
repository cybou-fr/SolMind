import FoundationModels
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - On-Ramp Tool (MoonPay Sandbox)

struct OnRampTool: Tool {
    let name = "buyWithFiat"
    let description = "Open MoonPay sandbox to buy SOL with fiat. Demo only (test card 4242 4242 4242 4242)."

    private let walletManager: WalletManager

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }

    @Generable
    struct Arguments {
        @Guide(description: "Fiat amount (default 50)")
        var amount: Double?
        @Guide(description: "Currency code (default usd)")
        var currency: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        // Build MoonPay sandbox URL
        var components = URLComponents(string: "https://buy-sandbox.moonpay.com")!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: AppSettings.shared.effectiveMoonpayAPIKey),
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

    private func openURL(_ url: URL) {
#if os(macOS)
        NSWorkspace.shared.open(url)
#else
        UIApplication.shared.open(url)
#endif
    }
}
