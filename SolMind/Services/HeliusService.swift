import Foundation

// MARK: - Helius DAS API Service

class HeliusService {
    private let apiKey: String
    private let baseURL: URL

    init(apiKey: String = Secrets.heliusAPIKey) {
        self.apiKey = apiKey
        self.baseURL = URL(string: "https://devnet.helius-rpc.com/")!
    }

    // MARK: - getAssetsByOwner (DAS)

    func getAssetsByOwner(owner: String, limit: Int = 100) async throws -> [NFTAsset] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-key", value: apiKey)]
        guard let url = components.url else { throw HeliusError.invalidURL }

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getAssetsByOwner",
            "params": [
                "ownerAddress": owner,
                "page": 1,
                "limit": limit,
                "displayOptions": ["showCollectionMetadata": true]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct DASResponse: Decodable {
            let result: DASResult?
        }
        struct DASResult: Decodable {
            let items: [DASItem]
        }
        struct DASItem: Decodable {
            let id: String
            let content: DASContent?
            let grouping: [DASGrouping]?
        }
        struct DASContent: Decodable {
            let metadata: DASMetadata?
            let links: DASLinks?
        }
        struct DASMetadata: Decodable {
            let name: String?
        }
        struct DASLinks: Decodable {
            let image: String?
        }
        struct DASGrouping: Decodable {
            let groupKey: String
            let groupValue: String
        }

        let response = try JSONDecoder().decode(DASResponse.self, from: data)
        return response.result?.items.map { item in
            NFTAsset(
                id: item.id,
                name: item.content?.metadata?.name ?? "Unknown NFT",
                imageURL: item.content?.links?.image.flatMap { URL(string: $0) },
                collectionName: item.grouping?.first(where: { $0.groupKey == "collection" })?.groupValue
            )
        } ?? []
    }

    // MARK: - mintCompressedNft (Helius DAS)

    /// Mints a compressed NFT on devnet using the Helius RPC extension.
    /// Helius covers the transaction fee; no wallet signature required.
    func mintCompressedNft(
        name: String,
        symbol: String,
        description: String,
        owner: String,
        imageUrl: String,
        attributes: [[String: String]] = []
    ) async throws -> MintNFTResult {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-key", value: apiKey)]
        guard let url = components.url else { throw HeliusError.invalidURL }

        let attributeObjects: [[String: String]] = attributes.isEmpty
            ? [["trait_type": "Created with", "value": "SolMind"]]
            : attributes

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "solmind-mint",
            "method": "mintCompressedNft",
            "params": [
                "name": name,
                "symbol": symbol.uppercased(),
                "owner": owner,
                "description": description,
                "attributes": attributeObjects,
                "imageUrl": imageUrl.isEmpty ? "https://placehold.co/400x400/1a1a2e/white?text=\(symbol.uppercased())" : imageUrl,
                "externalUrl": "https://solmind.app",
                "sellerFeeBasisPoints": 0
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct MintResponse: Decodable {
            let result: MintResultBlock?
            let error: HeliusRPCError?
        }
        struct MintResultBlock: Decodable {
            let signature: String?
            let assetId: String?
        }
        struct HeliusRPCError: Decodable {
            let message: String
        }

        let response = try JSONDecoder().decode(MintResponse.self, from: data)
        if let err = response.error { throw HeliusError.rpcError(err.message) }
        guard let sig = response.result?.signature else {
            throw HeliusError.rpcError("mintCompressedNft returned no signature")
        }
        return MintNFTResult(
            signature: sig,
            assetId: response.result?.assetId ?? "unknown"
        )
    }
}

// MARK: - Models

struct MintNFTResult {
    let signature: String
    let assetId: String
}

struct NFTAsset: Identifiable {
    let id: String
    let name: String
    let imageURL: URL?
    let collectionName: String?
}

enum HeliusError: LocalizedError {
    case invalidURL
    case rpcError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Helius URL."
        case .rpcError(let msg): return "Helius error: \(msg)"
        }
    }
}
