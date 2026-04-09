import SwiftUI

// MARK: - Wallet Setup / Onboarding View

struct WalletSetupView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showAddress = false
    @State private var airdropStatus: String?
    // Import flow
    @State private var showImportSheet = false
    @State private var importKeyText = ""
    @State private var isImporting = false
    @State private var importError: String?

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
                        .disabled(isCreating || isImporting)

                        Button {
                            importKeyText = ""
                            importError = nil
                            showImportSheet = true
                        } label: {
                            Label("Import Existing Wallet", systemImage: "arrow.down.circle")
                                .frame(maxWidth: 280)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(isCreating || isImporting)

                        Text("Create a new wallet or import from Phantom / Solflare using your private key.")
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
        .sheet(isPresented: $showImportSheet) {
            importSheet
        }
    }

    // MARK: - Import Sheet

    @ViewBuilder
    private var importSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste 64-byte base58 private key…", text: $importKeyText, axis: .vertical)
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                } header: {
                    Text("Private Key")
                } footer: {
                    Text("Paste a 64-byte base58 key exported from SolMind, Phantom, or Solflare. Your key never leaves this device.")
                }

                Section {
                    Button {
                        Task { await doImport() }
                    } label: {
                        if isImporting {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Importing…")
                            }
                        } else {
                            Text("Import Wallet")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .bold()
                        }
                    }
                    .disabled(importKeyText.trimmingCharacters(in: .whitespaces).isEmpty || isImporting)
                }

                if let importError {
                    Section {
                        Text(importError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Import Wallet")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showImportSheet = false }
                }
            }
        }
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

    private func doImport() async {
        isImporting = true
        importError = nil
        defer { isImporting = false }
        do {
            _ = try await walletViewModel.importWallet(
                privateKeyBase58: importKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            showImportSheet = false
            // walletViewModel.isWalletReady is now true → ContentView transitions automatically
        } catch {
            importError = error.localizedDescription
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
