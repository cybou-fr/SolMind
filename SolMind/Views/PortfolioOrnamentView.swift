import SwiftUI

// MARK: - visionOS Ornament: compact portfolio summary attached to window edge

struct PortfolioOrnamentView: View {
    @Environment(WalletViewModel.self) private var walletViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(walletViewModel.isWalletReady ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(walletViewModel.displayAddress)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(walletViewModel.solBalance, format: .number.precision(.fractionLength(4)))
                    .font(.title3.bold())
                Text("SOL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let total = walletViewModel.totalPortfolioUSD {
                Text(total, format: .currency(code: "USD"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if !walletViewModel.tokenBalances.isEmpty {
                Divider()
                ForEach(walletViewModel.tokenBalances.prefix(3)) { token in
                    HStack {
                        Text(token.symbol)
                            .font(.caption.bold())
                        Spacer()
                        Text(token.uiAmount, format: .number.precision(.fractionLength(2)))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                Task { await walletViewModel.refreshBalance() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .tint(.accentColor)
        }
        .padding(12)
        .frame(width: 180)
    }
}
