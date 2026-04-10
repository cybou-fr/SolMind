import FoundationModels
import Foundation

// MARK: - Mint NFT Tool (Helius Compressed NFT)

struct MintNFTTool: Tool {
    let name = "mintNFT"
    let description = "Mint a compressed NFT on devnet via Helius (free). Supports custom image URL and traits. Requires confirmation."

    private let walletManager: WalletManager
    private let heliusService: HeliusService
    private let confirmationHandler: TransactionConfirmationHandler

    init(walletManager: WalletManager, heliusService: HeliusService, confirmationHandler: TransactionConfirmationHandler) {
        self.walletManager = walletManager
        self.heliusService = heliusService
        self.confirmationHandler = confirmationHandler
    }

    @Generable
    struct Arguments {
        @Guide(description: "NFT display name")
        var name: String

        @Guide(description: "Collection symbol e.g. COOL")
        var symbol: String

        @Guide(description: "Short NFT description")
        var description: String

        @Guide(description: "Public image URL; leave empty for default")
        var imageUrl: String?

        @Guide(description: "Traits as 'Type=Value' e.g. ['Color=Blue','Rarity=Rare']")
        var traits: [String]?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let owner = walletManager.publicKey else {
            return "⚠️ TERMINAL: Wallet not connected. Do NOT retry automatically."
        }
        let apiKey = AppSettings.shared.effectiveHeliusAPIKey
        guard !apiKey.isEmpty else {
            return "⚠️ TERMINAL: Helius API key is not configured. Go to Settings → API Keys and enter a valid Helius devnet key, then try again. Do NOT retry automatically."
        }

        let preview = TransactionPreview(
            action: "mint",
            amount: 1,
            tokenSymbol: "NFT",
            recipient: owner,
            estimatedFee: 0.0,
            summary: "Mint compressed NFT '\(arguments.name)' [\(arguments.symbol.uppercased())] on devnet (fee: FREE via Helius)"
        )

        guard await confirmationHandler.requestConfirmation(preview) else {
            return "NFT mint cancelled."
        }

        await MainActor.run { ToastManager.shared.info("Minting NFT…") }

        // Parse traits from "Key=Value" strings
        let attributes: [[String: String]] = arguments.traits?.compactMap { trait in
            let parts = trait.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return ["trait_type": parts[0].trimmingCharacters(in: .whitespaces),
                    "value": parts[1].trimmingCharacters(in: .whitespaces)]
        } ?? [["trait_type": "Created with", "value": "SolMind"]]

        do {
            let result = try await heliusService.mintCompressedNft(
                name: arguments.name,
                symbol: arguments.symbol,
                description: arguments.description,
                owner: owner,
                imageUrl: arguments.imageUrl ?? "",
                attributes: attributes
            )

            await MainActor.run { ToastManager.shared.success("✓ NFT '\(arguments.name)' minted!") }
            return """
            ✅ DEVNET: NFT minted!
            Name: \(arguments.name) | Symbol: \(arguments.symbol.uppercased())
            Asset ID: \(result.assetId)
            TX: \(result.signature.prefix(12))…
            """
        } catch {
            return "⚠️ TERMINAL: NFT mint failed — \(error.localizedDescription). Do NOT retry automatically. The user should check their Helius API key in Settings and try again manually."
        }
    }
}
