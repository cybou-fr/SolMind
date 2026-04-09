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
    // Export private key
    // Export private key
    @State private var exportCandidate: String?        // address to export (triggers confirm dialog)
    @State private var exportedKey: String?            // loaded base58 private key
    @State private var isKeyRevealed = false
    @State private var keyCopied = false
    @State private var showExportSheet = false
    // Import private key
    @State private var showImportSheet = false
    @State private var importKeyText = ""
    @State private var isImporting = false

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

                Button {
                    importKeyText = ""
                    error = nil
                    showImportSheet = true
                } label: {
                    Label("Import Existing Wallet", systemImage: "arrow.down.circle")
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
        // Export — confirmation before revealing
        .confirmationDialog(
            "Export Private Key",
            isPresented: Binding(get: { exportCandidate != nil && !showExportSheet },
                                 set: { if !$0 { exportCandidate = nil } }),
            titleVisibility: .visible
        ) {
            Button("Show Private Key", role: .destructive) {
                loadExportKey()
            }
            Button("Cancel", role: .cancel) { exportCandidate = nil }
        } message: {
            Text("Never share your private key. Anyone who has it can access all funds in this wallet.")
        }
        // Export sheet — blurred reveal
        .sheet(isPresented: $showExportSheet, onDismiss: clearExportState) {
            exportKeySheet
        }
        // Import sheet
        .sheet(isPresented: $showImportSheet) {
            importWalletSheet
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
            Button {
                exportCandidate = address
            } label: {
                Label("Export Key", systemImage: "key")
            }
            .tint(.orange)
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
            Divider()
            Button {
                exportCandidate = address
            } label: {
                Label("Export Private Key…", systemImage: "key")
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

    // MARK: - Export Key Sheet

    @ViewBuilder
    private var exportKeySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Warning banner
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Never share your private key. Anyone with access to it can steal all funds.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                    // Address label
                    if let addr = exportCandidate {
                        Text("\(addr.prefix(8))…\(addr.suffix(8))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    // Key display with blur/reveal
                    ZStack {
                        if let key = exportedKey {
                            Text(key)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .padding()
                                .blur(radius: isKeyRevealed ? 0 : 10)
                                .animation(.easeInOut(duration: 0.25), value: isKeyRevealed)

                            if !isKeyRevealed {
                                Button {
                                    isKeyRevealed = true
                                } label: {
                                    Label("Tap to reveal", systemImage: "eye")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(.regularMaterial, in: Capsule())
                                }
                            }
                        } else {
                            ProgressView()
                                .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { if exportedKey != nil { isKeyRevealed = true } }

                    // Copy button
                    Button {
                        guard let key = exportedKey else { return }
#if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(key, forType: .string)
#else
                        UIPasteboard.general.string = key
#endif
                        keyCopied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            keyCopied = false
                        }
                    } label: {
                        Label(keyCopied ? "Copied!" : "Copy Private Key",
                              systemImage: keyCopied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(keyCopied ? .green : .accentColor)
                    .disabled(exportedKey == nil)

                    Text("This key is in Phantom/Solflare compatible format (64-byte base58).")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Private Key")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showExportSheet = false }
                }
            }
        }
    }

    // MARK: - Export helpers

    private func loadExportKey() {
        guard let address = exportCandidate else { return }
        do {
            exportedKey = try LocalWallet.exportPrivateKeyBase58(address: address)
            isKeyRevealed = false
            keyCopied = false
            showExportSheet = true
        } catch {
            self.error = "Could not load private key: \(error.localizedDescription)"
            exportCandidate = nil
        }
    }

    private func clearExportState() {
        exportCandidate = nil
        exportedKey = nil
        isKeyRevealed = false
        keyCopied = false
    }

    // MARK: - Import Wallet Sheet

    @ViewBuilder
    private var importWalletSheet: some View {
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
                    Text("Paste a 64-byte base58 private key exported from SolMind, Phantom, or Solflare. Your key never leaves this device.")
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

                if let error {
                    Section {
                        Text(error)
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
                    Button("Cancel") {
                        showImportSheet = false
                        error = nil
                    }
                }
            }
        }
    }

    private func doImport() async {
        isImporting = true
        error = nil
        defer { isImporting = false }
        do {
            let address = try await walletViewModel.importWallet(
                privateKeyBase58: importKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            showImportSheet = false
            ToastManager.shared.success("Wallet imported: \(address.prefix(4))…\(address.suffix(4))")
        } catch {
            self.error = error.localizedDescription
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
            ToastManager.shared.success("New wallet created: \(address.prefix(4))…\(address.suffix(4))")
        } catch {
            self.error = error.localizedDescription
            ToastManager.shared.error("Wallet creation failed")
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
