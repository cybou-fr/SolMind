import SwiftUI

// MARK: - Wallet Picker
//
// Lists all keypairs stored on the device. Lets the user:
//   • Switch the active wallet
//   • Generate a new keypair
//   • Delete a wallet (requires confirmation; last wallet is protected)

struct WalletPickerView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var isGenerating = false
    @State private var error: String?
    @State private var deleteCandidate: String?
    @State private var copiedAddress: String?

    var body: some View {
        List {
            Section {
                ForEach(walletViewModel.allAddresses, id: \.self) { address in
                    walletRow(address: address)
                }
            } header: {
                Text("Wallets on this device")
            } footer: {
                Text("Private keys are stored in the Apple Keychain and never leave this device.")
                    .font(.caption)
            }

            Section {
                Button {
                    Task { await generateNew() }
                } label: {
                    if isGenerating {
                        Label("Generating…", systemImage: "ellipsis.circle")
                    } else {
                        Label("Generate New Wallet", systemImage: "plus.circle")
                    }
                }
                .disabled(isGenerating)
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Wallets")
#if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
#endif
        .confirmationDialog(
            "Delete Wallet",
            isPresented: Binding(get: { deleteCandidate != nil },
                                 set: { if !$0 { deleteCandidate = nil } }),
            titleVisibility: .visible
        ) {
            if let address = deleteCandidate {
                Button("Delete \(address.prefix(4))…\(address.suffix(4))", role: .destructive) {
                    Task { await doDelete(address: address) }
                }
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
            }
        } message: {
            Text("The private key will be permanently removed from the Keychain.")
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func walletRow(address: String) -> some View {
        HStack(spacing: 12) {
            // Active indicator
            Circle()
                .fill(address == walletViewModel.publicKey ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(address)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                if address == walletViewModel.publicKey {
                    Text("Active")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Copy button
            Button {
                copyAddress(address)
            } label: {
                Image(systemName: copiedAddress == address ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copiedAddress == address ? .green : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Copy address")

            // Switch button (only for inactive wallets)
            if address != walletViewModel.publicKey {
                Button("Switch") {
                    Task { await switchTo(address: address) }
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .tint(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if walletViewModel.allAddresses.count > 1 {
                Button(role: .destructive) {
                    deleteCandidate = address
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            Button {
                copyAddress(address)
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }
            if address != walletViewModel.publicKey {
                Button {
                    Task { await switchTo(address: address) }
                } label: {
                    Label("Make Active", systemImage: "checkmark.circle")
                }
            }
            if walletViewModel.allAddresses.count > 1 {
                Divider()
                Button(role: .destructive) {
                    deleteCandidate = address
                } label: {
                    Label("Delete Wallet", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Actions

    private func generateNew() async {
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        do {
            let address = try await walletViewModel.generateNewWallet()
            await walletViewModel.refreshBalance()
            _ = address
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func switchTo(address: String) async {
        error = nil
        do {
            try await walletViewModel.switchWallet(to: address)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func doDelete(address: String) async {
        error = nil
        deleteCandidate = nil
        do {
            try await walletViewModel.deleteWallet(address: address)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func copyAddress(_ address: String) {
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
#else
        UIPasteboard.general.string = address
#endif
        copiedAddress = address
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedAddress = nil
        }
    }
}

#Preview {
    NavigationStack {
        WalletPickerView()
    }
    .environment(WalletViewModel())
}
