import SwiftUI

// MARK: - Portfolio View

struct PortfolioView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var isRefreshing = false

    var body: some View {
        List {
            // Total portfolio value header
            if let total = walletViewModel.totalPortfolioUSD {
                Section {
                    VStack(spacing: 4) {
                        Text("Total Portfolio Value")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(total, format: .currency(code: "USD"))
                            .font(.largeTitle.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }

            // SOL Balance
            Section("Wallet") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("SOL Balance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(walletViewModel.solBalance, format: .number.precision(.fractionLength(6)))
                                .font(.title2.bold())
                            Text("SOL")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        if let usdValue = walletViewModel.solUSDValue {
                            Text(usdValue, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        Task {
                            isRefreshing = true
                            await walletViewModel.refreshBalance()
                            await walletViewModel.refreshTransactionHistory()
                            isRefreshing = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)

                Text(walletViewModel.displayAddress)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            // Token Balances
            if !walletViewModel.tokenBalances.isEmpty {
                Section("Tokens") {
                    ForEach(walletViewModel.tokenBalances) { token in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(token.symbol)
                                    .font(.headline)
                                Text(token.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(token.uiAmount, format: .number.precision(.fractionLength(4)))
                                    .font(.headline)
                                if let usdValue = token.usdValue {
                                    Text(usdValue, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Recent Activity
            Section {
                if walletViewModel.isLoadingTransactions {
                    HStack {
                        ProgressView()
                        Text("Loading transactions…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if walletViewModel.recentTransactions.isEmpty {
                    Text("No recent transactions")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(walletViewModel.recentTransactions) { tx in
                        transactionRow(tx)
                    }
                }
            } header: {
                Text("Recent Activity")
            } footer: {
                if !walletViewModel.recentTransactions.isEmpty {
                    Text("Showing last \(walletViewModel.recentTransactions.count) transactions on devnet.")
                        .font(.caption2)
                }
            }

            // Quick Actions
            Section("Quick Actions") {
                Button {
                    Task { _ = try? await walletViewModel.requestAirdrop(solAmount: 1.0) }
                } label: {
                    Label("Get 1 Devnet SOL (Faucet)", systemImage: "drop.fill")
                }
                .tint(.accentColor)
            }
        }
        .navigationTitle("Portfolio")
        .refreshable {
            await walletViewModel.refreshBalance()
            await walletViewModel.refreshTransactionHistory()
        }
        .task {
            if walletViewModel.recentTransactions.isEmpty {
                await walletViewModel.refreshTransactionHistory()
            }
        }
    }

    // MARK: - Transaction Row

    @ViewBuilder
    private func transactionRow(_ tx: TransactionModel) -> some View {
        Link(destination: tx.explorerURL) {
            HStack(spacing: 10) {
                Image(systemName: tx.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(tx.isSuccess ? Color.green : Color.red)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.signature.prefix(8) + "…" + tx.signature.suffix(4))
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                    Text(tx.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PortfolioView()
    }
    .environment(WalletViewModel())
}
