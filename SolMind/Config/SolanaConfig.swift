import Foundation

enum SolanaNetwork {
    static let cluster = "devnet"

    /// Primary RPC URL — uses Helius devnet when an API key is configured (higher rate limits +
    /// NFT DAS APIs), otherwise falls back to the free public devnet endpoint.
    ///
    /// Reads UserDefaults directly so this can be called from any actor context without
    /// crossing a @MainActor boundary (avoids the Swift 6 nonisolated warning).
    static var rpcURL: URL {
        let stored = UserDefaults.standard.string(forKey: "solmind.heliusAPIKey") ?? ""
        let key = stored.isEmpty ? Secrets.heliusAPIKey : stored
        if !key.isEmpty {
            return URL(string: "https://devnet.helius-rpc.com/?api-key=\(key)")!
        }
        return URL(string: "https://api.devnet.solana.com")!
    }

    static let wsURL = URL(string: "wss://api.devnet.solana.com")!
    static let explorerBaseURL = "https://explorer.solana.com"

    static func explorerURL(signature: String) -> URL {
        URL(string: "\(explorerBaseURL)/tx/\(signature)?cluster=devnet")!
    }

    static func explorerURL(address: String) -> URL {
        URL(string: "\(explorerBaseURL)/address/\(address)?cluster=devnet")!
    }
}
