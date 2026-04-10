import SwiftUI

// MARK: - NFT Gallery View (Phase 4 — Helius DAS)

struct NFTGalleryView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var nfts: [NFTAsset] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedNFT: NFTAsset?
    @State private var showMintForm = false

    private let heliusService = HeliusService()
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)]

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading NFTs from Helius…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Could Not Load NFTs", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(error)
                        .font(.caption)
                } actions: {
                    Button("Try Again") { Task { await loadNFTs() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if nfts.isEmpty {
                ContentUnavailableView {
                    Label("No NFTs Found", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("No NFTs in this devnet wallet yet.\nAsk SolMind to mint a compressed NFT on devnet.")
                        .multilineTextAlignment(.center)
                } actions: {
                    Text("Open the Chat tab and say: **\"Mint me an NFT\"**")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(nfts) { nft in
                            NFTCard(nft: nft)
                                .onTapGesture { selectedNFT = nft }
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding()
                }
                .refreshable { await loadNFTs() }
                .sheet(item: $selectedNFT) { nft in
                    NFTDetailView(nft: nft)
                }
            }
        }
        .navigationTitle("NFT Gallery")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                DevnetBadge()
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadNFTs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh NFTs")
                .disabled(isLoading)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showMintForm = true
                } label: {
                    Label("Mint NFT", systemImage: "plus.circle.fill")
                }
                .help("Mint a compressed NFT on devnet")
            }
        }
        .sheet(isPresented: $showMintForm) {
            MintNFTFormView(walletAddress: walletViewModel.publicKey ?? "") {
                // Refresh gallery after successful mint
                Task { await loadNFTs() }
            }
        }
        .task { await loadNFTs() }
    }

    // MARK: - Data Loading

    private func loadNFTs() async {
        guard let publicKey = walletViewModel.publicKey else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            nfts = try await heliusService.getAssetsByOwner(owner: publicKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Individual NFT Card

struct NFTCard: View {
    let nft: NFTAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Artwork
            Group {
                if let imageURL = nft.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderArtwork
                        case .empty:
                            ZStack {
                                placeholderArtwork
                                ProgressView()
                            }
                        @unknown default:
                            placeholderArtwork
                        }
                    }
                } else {
                    placeholderArtwork
                }
            }
            .frame(minHeight: 140)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(nft.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let collection = nft.collectionName {
                    Text(collection)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Link(destination: SolanaNetwork.explorerURL(address: nft.id)) {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
            .help("View on Solana Explorer")
            .padding(6)
        }
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "photo.artframe")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
            }
    }
}

#Preview {
    NavigationStack {
        NFTGalleryView()
    }
    .environment(WalletViewModel())
}

// MARK: - Mint NFT Form Sheet

struct MintNFTFormView: View {
    let walletAddress: String
    let onSuccess: () -> Void
    /// Called after a successful mint with (name, symbol, assetId, imageUrl).
    /// Used by ChatView to post the result back into the conversation.
    var onMinted: ((String, String, String, String?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var nftName: String = ""
    @State private var symbol: String = ""
    @State private var nftDescription: String = ""
    @State private var imageUrl: String = ""
    @State private var externalUrl: String = ""
    @State private var traitsText: String = ""   // "Color=Blue, Rarity=Rare"

    @State private var isMinting = false
    @State private var mintError: String?
    @State private var showConfirmation = false

    private let heliusService = HeliusService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name *", text: $nftName)
                    TextField("Symbol * (e.g. COOL)", text: $symbol)
                        .onChange(of: symbol) { _, new in
                            if new.count > 10 { symbol = String(new.prefix(10)) }
                        }
                    TextField("Description", text: $nftDescription, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text("Basics")
                }

                Section {
                    TextField("Image URL (https://…)", text: $imageUrl)
                        .textContentType(.URL)
#if os(iOS)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
#endif
                    if let url = URL(string: imageUrl), !imageUrl.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 160).clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                Label("Could not load preview", systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    TextField("External Link (https://…)", text: $externalUrl)
                        .textContentType(.URL)
#if os(iOS)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
#endif
                } header: {
                    Text("Artwork & Links")
                } footer: {
                    Text("Image URL: the NFT artwork. External Link: a website for the NFT (optional, e.g. your project page).")
                        .font(.caption2)
                }

                Section {
                    TextField("Traits (e.g. Color=Blue, Rarity=Rare)", text: $traitsText, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Traits")
                } footer: {
                    Text("Comma-separated Key=Value pairs. Example: Background=Space, Edition=1")
                        .font(.caption2)
                }

                if let error = mintError {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Mint Compressed NFT")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mint") {
                        showConfirmation = true
                    }
                    .disabled(nftName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              symbol.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isMinting)
                    .bold()
                }
            }
            .confirmationDialog(
                "Mint \"\(nftName)\" [\(symbol.uppercased())] on Devnet?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Mint NFT (FREE via Helius)") {
                    Task { await mintNFT() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This mints a compressed cNFT on Solana Devnet. No real funds are used.")
            }
            .overlay {
                if isMinting {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Minting NFT…")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    // MARK: - Mint

    private func mintNFT() async {
        isMinting = true
        mintError = nil

        let apiKey = AppSettings.shared.effectiveHeliusAPIKey
        guard !apiKey.isEmpty else {
            mintError = "Helius API key not configured. Go to Settings → API Keys."
            isMinting = false
            return
        }
        guard !walletAddress.isEmpty else {
            mintError = "Wallet not connected."
            isMinting = false
            return
        }

        // Parse traits from "Key=Value, Key2=Value2"
        let attributes: [[String: String]] = traitsText
            .split(separator: ",")
            .compactMap { part -> [String: String]? in
                let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard pair.count == 2, !pair[0].isEmpty else { return nil }
                return ["trait_type": pair[0], "value": pair[1]]
            }

        do {
            let result = try await heliusService.mintCompressedNft(
                name: nftName.trimmingCharacters(in: .whitespaces),
                symbol: symbol.uppercased().trimmingCharacters(in: .whitespaces),
                description: nftDescription.trimmingCharacters(in: .whitespaces),
                owner: walletAddress,
                imageUrl: imageUrl.trimmingCharacters(in: .whitespaces),
                externalUrl: externalUrl.trimmingCharacters(in: .whitespaces),
                attributes: attributes
            )
            isMinting = false
            ToastManager.shared.success("✓ NFT '\(nftName)' minted!")
            let resolvedImageUrl = imageUrl.trimmingCharacters(in: .whitespaces)
            onMinted?(nftName, symbol.uppercased(), result.assetId, resolvedImageUrl.isEmpty ? nil : resolvedImageUrl)
            onSuccess()
            dismiss()
        } catch {
            isMinting = false
            mintError = error.localizedDescription
        }
    }
}