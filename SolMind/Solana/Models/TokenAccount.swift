import Foundation

struct TokenAccount: Identifiable {
    let id = UUID()
    let pubkey: String
    let mint: String
    let owner: String
    let decimals: Int
    let rawAmount: UInt64
    let uiAmount: Double

    var displayAmount: String {
        uiAmount.formatted(.number.precision(.fractionLength(4)))
    }
}
