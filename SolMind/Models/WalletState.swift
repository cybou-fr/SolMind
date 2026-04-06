import Foundation

struct WalletState {
    var publicKey: String?
    var solBalance: Double = 0
    var tokenBalances: [TokenBalance] = []
    var isConnected: Bool { publicKey != nil }

    var displayAddress: String {
        guard let pk = publicKey else { return "Not connected" }
        return "\(pk.prefix(4))...\(pk.suffix(4))"
    }
}

struct TokenBalance: Identifiable {
    let id = UUID()
    let mint: String
    let symbol: String
    let name: String
    let decimals: Int
    let rawAmount: UInt64
    var usdValue: Double?

    var uiAmount: Double {
        Double(rawAmount) / pow(10.0, Double(decimals))
    }
}
