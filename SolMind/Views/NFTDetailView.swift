import SwiftUI

// MARK: - NFT Detail Sheet

struct NFTDetailView: View {
    let nft: NFTAsset
    @Environment(\.dismiss) private var dismiss
    @State private var copiedAssetID = false
    @State private var liveAsset: NFTAsset?       // refreshed from Helius DAS
    @State private var isFetchingMeta = false

    private var displayed: NFTAsset { liveAsset ?? nft }

    private let heliusService = HeliusService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: Artwork
                    NFTDetailImage(imageURL: displayed.imageURL)

                    VStack(alignment: .leading, spacing: 6) {
                        // Name
                        HStack {
                            Text(displayed.name)
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if isFetchingMeta {
                                ProgressView().scaleEffect(0.7)
                            }
                        }

                        // Collection
                        if let collection = displayed.collectionName, !collection.isEmpty {
                            Label(collection, systemImage: "rectangle.stack.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // MARK: Asset ID row
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Asset ID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(displayed.id)
                                    .font(.caption.monospaced())
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Button {
                                    copyToClipboard(displayed.id)
                                    copiedAssetID = true
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        copiedAssetID = false
                                    }
                                } label: {
                                    Image(systemName: copiedAssetID ? "checkmark.circle.fill" : "doc.on.doc")
                                        .foregroundStyle(copiedAssetID ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(copiedAssetID ? "Copied" : "Copy Asset ID")

                                Link(destination: SolanaNetwork.explorerURL(address: displayed.id)) {
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("View on Explorer")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // MARK: Description
                    if let desc = displayed.nftDescription, !desc.isEmpty {
                        GroupBox("Description") {
                            Text(desc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // MARK: Attributes
                    if !displayed.attributes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Attributes")
                                .font(.headline)
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 130), spacing: 10)],
                                spacing: 10
                            ) {
                                ForEach(displayed.attributes, id: \.trait) { attr in
                                    AttributeChipView(trait: attr.trait, value: attr.value)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("NFT Details")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                isFetchingMeta = true
                if let fresh = try? await heliusService.getAsset(id: nft.id) {
                    liveAsset = fresh
                }
                isFetchingMeta = false
            }
        }
    }

    private func copyToClipboard(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
}

// MARK: - NFT Detail Image (large hero)

private struct NFTDetailImage: View {
    let imageURL: URL?

    var body: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack { placeholder; ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.4), Color.indigo.opacity(0.4)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("SolMind NFT")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
    }
}

// MARK: - Attribute Chip

private struct AttributeChipView: View {
    let trait: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trait.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    NFTDetailView(nft: NFTAsset(
        id: "7GCihgDB8fe6KNjn2MktkpxnNLjGHgSJ4mh3m8h12345",
        name: "SolMind Pioneer #1",
        imageURL: nil,
        collectionName: "SolMind Collection",
        nftDescription: "A unique compressed NFT minted on Solana devnet via SolMind AI.",
        attributes: [
            (trait: "Background", value: "Deep Space"),
            (trait: "Rarity", value: "Rare"),
            (trait: "Created with", value: "SolMind")
        ]
    ))
}
