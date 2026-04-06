import SwiftUI

// MARK: - Transaction Preview Confirmation Card

struct TransactionPreviewCard: View {
    let preview: TransactionPreview
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Transaction Preview", systemImage: "doc.badge.clock")
                    .font(.headline)
                Spacer()
                DevnetBadge()
            }

            Divider()

            // Details
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Action").foregroundStyle(.secondary).font(.caption)
                    Text(preview.action.capitalized).font(.caption.bold())
                }
                GridRow {
                    Text("Amount").foregroundStyle(.secondary).font(.caption)
                    Text("\(preview.amount, format: .number.precision(.fractionLength(4))) \(preview.tokenSymbol)")
                        .font(.caption.bold())
                }
                if !preview.recipient.isEmpty {
                    GridRow {
                        Text("To").foregroundStyle(.secondary).font(.caption)
                        Text(preview.recipient)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                GridRow {
                    Text("Network Fee").foregroundStyle(.secondary).font(.caption)
                    Text("\(preview.estimatedFee, format: .number.precision(.fractionLength(6))) SOL")
                        .font(.caption.bold())
                }
            }

            Divider()

            // Summary
            Text(preview.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Action buttons
            HStack(spacing: 12) {
                Button(role: .destructive) { onCancel() } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button { onConfirm() } label: {
                    Label("Confirm", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.4)))
    }
}

#Preview {
    TransactionPreviewCard(
        preview: TransactionPreview(
            action: "send",
            amount: 0.5,
            tokenSymbol: "SOL",
            recipient: "3A5vT2jX7bN9Q1mW6kZpRxE8dYuL4cHoF0sVgInCoK2",
            estimatedFee: 0.000005,
            summary: "Send 0.5 SOL to 3A5v...oK2 on devnet."
        ),
        onConfirm: {},
        onCancel: {}
    )
    .padding()
}
