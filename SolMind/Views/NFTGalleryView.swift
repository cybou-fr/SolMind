import SwiftUI

// MARK: - NFT Gallery View (Phase 4 — Helius DAS)

struct NFTGalleryView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @State private var nfts: [NFTAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    Text("No NFTs in this devnet wallet yet.\nTry minting some on devnet first.")
                        .multilineTextAlignment(.center)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(nfts) { nft in
                            NFTCard(nft: nft)
                        }
                    }
                    .padding()
                }
                .refreshable { await loadNFTs() }
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
