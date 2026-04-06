import SwiftUI

// MARK: - Portfolio View

struct PortfolioView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var isRefreshing = false

    var body: some View {
        List {
            // SOL Balance
            Section("Wallet") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("SOL Balance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(walletViewModel.solBalance, format: .number.precision(.fractionLength(6)))
                            .font(.title2.bold())
                        + Text(" SOL")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            isRefreshing = true
                            await walletViewModel.refreshBalance()
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
        }
    }
}

#Preview {
    NavigationStack {
        PortfolioView()
    }
    .environment(WalletViewModel())
}
