import FoundationModels

// MARK: - Guided Generation Model

@Generable
struct TransactionPreview {
    @Guide(description: "The action being performed: send, swap, stake, or faucet")
    var action: String

    @Guide(description: "Amount in token units (e.g. 1.5)")
    var amount: Double

    @Guide(description: "Token symbol (e.g. SOL, USDC)")
    var tokenSymbol: String

    @Guide(description: "Recipient address or .sol domain. Empty string for non-transfer actions.")
    var recipient: String

    @Guide(description: "Estimated network fee in SOL")
    var estimatedFee: Double

    @Guide(description: "One-sentence human-readable summary of this transaction")
    var summary: String
}
