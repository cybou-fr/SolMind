import Foundation

// MARK: - Helius DAS API Service

class HeliusService {
    /// Always reads the current key — survives Settings changes without re-init.
    private var apiKey: String { AppSettings.shared.effectiveHeliusAPIKey }
    private let baseURL: URL

    init() {
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
            let description: String?
            let attributes: [DASAttribute]?
        }
        struct DASAttribute: Decodable {
            let traitType: String?
            let value: String?
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                traitType = try c.decodeIfPresent(String.self, forKey: .traitType)
                // value can be String or Number in DAS responses
                if let s = try? c.decodeIfPresent(String.self, forKey: .value) {
                    value = s
                } else if let n = try? c.decodeIfPresent(Double.self, forKey: .value) {
                    value = n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
                } else {
                    value = nil
                }
            }
            enum CodingKeys: String, CodingKey { case traitType, value }
        }
        struct DASLinks: Decodable {
            let image: String?
        }
        struct DASGrouping: Decodable {
            let groupKey: String
            let groupValue: String
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(DASResponse.self, from: data)
        return response.result?.items.map { item in
            let attrs = item.content?.metadata?.attributes?.compactMap { attr -> (trait: String, value: String)? in
                guard let t = attr.traitType, let v = attr.value else { return nil }
                return (trait: t, value: v)
            } ?? []
            return NFTAsset(
                id: item.id,
                name: item.content?.metadata?.name ?? "Unknown NFT",
                imageURL: item.content?.links?.image.flatMap { URL(string: $0) },
                collectionName: item.grouping?.first(where: { $0.groupKey == "collection" })?.groupValue,
                nftDescription: item.content?.metadata?.description,
                attributes: attrs
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
        externalUrl: String = "",
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
                "imageUrl": imageUrl.isEmpty ? "https://placehold.co/400x400/6C5CE7/FFFFFF?text=SolMind" : imageUrl,
                "externalUrl": externalUrl.isEmpty ? "https://solmind.app" : externalUrl,
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(MintResponse.self, from: data)
        if let err = response.error { throw HeliusError.rpcError(err.message) }
        guard let sig = response.result?.signature else {
            // Surface raw response for easier debugging
            let raw = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw HeliusError.rpcError("mintCompressedNft returned no signature. Response: \(raw.prefix(300))")
        }
        return MintNFTResult(
            signature: sig,
            assetId: response.result?.assetId ?? "unknown"
        )
    }

    // MARK: - getAsset (single asset by ID)

    func getAsset(id: String) async throws -> NFTAsset {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "api-key", value: apiKey)]
        guard let url = components.url else { throw HeliusError.invalidURL }

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getAsset",
            "params": ["id": id]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct SingleAssetResponse: Decodable {
            struct Result: Decodable {
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
                let description: String?
                let attributes: [DASAttribute]?
            }
            struct DASAttribute: Decodable {
                let traitType: String?
                let value: String?
                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    traitType = try c.decodeIfPresent(String.self, forKey: .traitType)
                    if let s = try? c.decodeIfPresent(String.self, forKey: .value) { value = s }
                    else if let n = try? c.decodeIfPresent(Double.self, forKey: .value) {
                        value = n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
                    } else { value = nil }
                }
                enum CodingKeys: String, CodingKey { case traitType, value }
            }
            struct DASLinks: Decodable { let image: String? }
            struct DASGrouping: Decodable { let groupKey: String; let groupValue: String }

            let result: Result?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(SingleAssetResponse.self, from: data)
        guard let item = response.result else { throw HeliusError.rpcError("getAsset: empty result") }
        let attrs = item.content?.metadata?.attributes?.compactMap { attr -> (trait: String, value: String)? in
            guard let t = attr.traitType, let v = attr.value else { return nil }
            return (trait: t, value: v)
        } ?? []
        return NFTAsset(
            id: item.id,
            name: item.content?.metadata?.name ?? "Unknown NFT",
            imageURL: item.content?.links?.image.flatMap { URL(string: $0) },
            collectionName: item.grouping?.first(where: { $0.groupKey == "collection" })?.groupValue,
            nftDescription: item.content?.metadata?.description,
            attributes: attrs
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
    let nftDescription: String?
    let attributes: [(trait: String, value: String)]

    init(id: String, name: String, imageURL: URL?, collectionName: String?,
         nftDescription: String? = nil, attributes: [(trait: String, value: String)] = []) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.collectionName = collectionName
        self.nftDescription = nftDescription
        self.attributes = attributes
    }
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
