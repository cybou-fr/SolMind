import SwiftUI

// MARK: - Wallet Setup / Onboarding View

struct WalletSetupView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showAddress = false
    @State private var airdropStatus: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / header
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("SolMind")
                    .font(.largeTitle.bold())
                Text("Your AI-powered Solana wallet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DevnetBadge()
            }

            // Wallet creation
            VStack(spacing: 16) {
                if let address = walletViewModel.publicKey, showAddress {
                    VStack(spacing: 8) {
                        Text("Wallet Created!")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text(address)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                        if let status = airdropStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                requestAirdrop()
                            } label: {
                                Label("Get Free Devnet SOL", systemImage: "drop.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Button {
                            createWallet()
                        } label: {
                            Label(isCreating ? "Creating…" : "Create New Wallet", systemImage: "plus.circle.fill")
                                .frame(maxWidth: 280)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isCreating)

                        Text("A new Ed25519 keypair will be generated and stored securely in your Keychain.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            Text("⚠️ This wallet is for DEVNET only. No real funds.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createWallet() {
        isCreating = true
        errorMessage = nil
        Task {
            await walletViewModel.setup()
            if walletViewModel.isWalletReady {
                withAnimation { showAddress = true }
            } else if let err = walletViewModel.setupError {
                errorMessage = err
            }
            isCreating = false
        }
    }

    private func requestAirdrop() {
        airdropStatus = "Requesting airdrop…"
        Task {
            do {
                let sig = try await walletViewModel.requestAirdrop(solAmount: 1.0)
                airdropStatus = "✅ Airdrop successful! Tx: \(sig.prefix(8))…"
                // Short delay then let ContentView transition to chat
                try await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                airdropStatus = "Airdrop failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    WalletSetupView()
        .environment(WalletViewModel())
}
