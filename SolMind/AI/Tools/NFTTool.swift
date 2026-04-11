import FoundationModels
import Foundation

// MARK: - NFT Tool (Helius DAS)

struct NFTTool: Tool {
    let name = "getNFTs"
    let description = "List NFTs owned by the active wallet via Helius DAS."

    private let walletManager: WalletManager
    private let heliusService: HeliusService

    init(walletManager: WalletManager, heliusService: HeliusService) {
        self.walletManager = walletManager
        self.heliusService = heliusService
    }

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard let publicKey = walletManager.publicKey else {
            return "Wallet not connected."
        }

        do {
            let nfts = try await heliusService.getAssetsByOwner(owner: publicKey)

            if nfts.isEmpty {
                return "No NFTs found in your devnet wallet. Try minting some on devnet first."
            }

            let list = nfts.prefix(20).map { nft in
                "• \(nft.name) (\(nft.collectionName ?? "No collection"))"
            }.joined(separator: "\n")

            return "Your NFTs on devnet (\(nfts.count) total):\n\(list)"
        } catch {
            return "Could not fetch NFTs: \(error.localizedDescription)"
        }
    }
}
