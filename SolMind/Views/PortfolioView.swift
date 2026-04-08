import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Portfolio View

struct PortfolioView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var isRefreshing = false
    @State private var rotationDegrees: Double = 0
    @State private var addressCopied = false
    @State private var copiedSignature: String? = nil

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
                            withAnimation(.linear(duration: 0.7).repeatForever(autoreverses: false)) {
                                rotationDegrees = 360
                            }
                            await walletViewModel.refreshBalance()
                            await walletViewModel.refreshTransactionHistory()
                            isRefreshing = false
                            withAnimation(.default) { rotationDegrees = 0 }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(rotationDegrees))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)

                Button {
                    copyAddress(walletViewModel.publicKey ?? "")
                } label: {
                    HStack(spacing: 5) {
                        Text(walletViewModel.displayAddress)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Image(systemName: addressCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(addressCopied ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Copy wallet address")
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

            // Zero-balance onboarding nudge
            if walletViewModel.solBalance == 0 && walletViewModel.tokenBalances.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Get started with devnet SOL", systemImage: "drop.fill")
                            .font(.headline)
                        Text("Your wallet is empty. Request free devnet SOL from the faucet to start experimenting — no real money involved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { _ = try? await walletViewModel.requestAirdrop(solAmount: 2.0) }
                        } label: {
                            Label("Request 2 Devnet SOL", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
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

    // MARK: - Helpers

    private func copyAddress(_ address: String) {
        #if os(iOS)
        UIPasteboard.general.string = address
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        #endif
        withAnimation { addressCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { addressCopied = false }
        }
    }

    // MARK: - Transaction Row

    @ViewBuilder
    private func transactionRow(_ tx: TransactionModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tx.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(tx.isSuccess ? Color.green : Color.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                // Full signature, monospaced, wraps on narrow screens
                Text(tx.signature)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(tx.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            // Copy button
            Button {
                copySignature(tx.signature)
            } label: {
                Image(systemName: copiedSignature == tx.signature ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(copiedSignature == tx.signature ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help("Copy full signature")

            // Explorer link
            Link(destination: tx.explorerURL) {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("View on Solana Explorer")
        }
        .contextMenu {
            Button {
                copySignature(tx.signature)
            } label: {
                Label("Copy Signature", systemImage: "doc.on.doc")
            }
            Link(destination: tx.explorerURL) {
                Label("Open in Explorer", systemImage: "arrow.up.right.square")
            }
        }
    }

    private func copySignature(_ signature: String) {
        #if os(iOS)
        UIPasteboard.general.string = signature
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(signature, forType: .string)
        #endif
        withAnimation { copiedSignature = signature }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiedSignature = nil }
        }
    }
}

#Preview {
    NavigationStack {
        PortfolioView()
    }
    .environment(WalletViewModel())
}
