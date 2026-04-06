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
}

// MARK: - Models

struct NFTAsset: Identifiable {
    let id: String
    let name: String
    let imageURL: URL?
    let collectionName: String?
}

enum HeliusError: LocalizedError {
    case invalidURL

    var errorDescription: String? { "Invalid Helius URL." }
}
