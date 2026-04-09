import FoundationModels
import Foundation

// MARK: - Mint NFT Tool (Helius Compressed NFT)

struct MintNFTTool: Tool {
    let name = "mintNFT"
    let description = """
    Mint a compressed NFT on Solana devnet for the connected wallet using Helius. \
    Helius covers the transaction fee — no SOL needed. Shows a native confirmation card before minting. \
    Do NOT ask the user to type 'confirmed: true'.
    """

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
        @Guide(description: "Display name for the NFT (e.g. 'SolMind Pioneer #1')")
        var name: String

        @Guide(description: "Short symbol/ticker for the NFT collection (e.g. 'SMND')")
        var symbol: String

        @Guide(description: "Human-readable description of the NFT")
        var description: String

        @Guide(description: "Direct URL to the NFT image. Leave empty to auto-generate a placeholder.")
        var imageUrl: String?

        @Guide(description: "Optional list of trait key=value pairs (e.g. ['Background=Blue', 'Rarity=Rare'])")
        var traits: [String]?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let owner = walletManager.publicKey else {
            return "Wallet not connected."
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
            ⚠️ DEVNET: Compressed NFT minted successfully!

            Name: \(arguments.name)
            Symbol: \(arguments.symbol.uppercased())
            Asset ID: \(result.assetId)
            Owner: \(owner)

            Transaction: \(SolanaNetwork.explorerURL(signature: result.signature).absoluteString)

            The NFT will appear in your gallery shortly. Refresh your NFT gallery to see it.
            """
        } catch {
            return "NFT mint failed: \(error.localizedDescription). Make sure your Helius API key is configured for devnet."
        }
    }
}
