import Foundation

struct TransactionModel: Identifiable {
    let id = UUID()
    let signature: String
    let slot: UInt64?
    let blockTime: Int64?
    let fee: UInt64
    let isSuccess: Bool
    let memo: String?

    var formattedDate: String {
        guard let bt = blockTime else { return "Unknown" }
        let date = Date(timeIntervalSince1970: TimeInterval(bt))
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var explorerURL: URL {
        SolanaNetwork.explorerURL(signature: signature)
    }
}
