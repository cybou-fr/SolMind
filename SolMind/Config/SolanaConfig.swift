import Foundation

enum SolanaNetwork {
    static let cluster = "devnet"
    static let rpcURL = URL(string: "https://api.devnet.solana.com")!
    static let wsURL = URL(string: "wss://api.devnet.solana.com")!
    static let explorerBaseURL = "https://explorer.solana.com"

    static func explorerURL(signature: String) -> URL {
        URL(string: "\(explorerBaseURL)/tx/\(signature)?cluster=devnet")!
    }

    static func explorerURL(address: String) -> URL {
        URL(string: "\(explorerBaseURL)/address/\(address)?cluster=devnet")!
    }
}
