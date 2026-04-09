import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QR Code Generator

/// Generates a high-res QR code image from any string using CoreImage.
struct QRCodeImage: View {
    let content: String
    var size: CGFloat = 200

    private var cgImage: CGImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let ciImage = filter.outputImage else { return nil }
        // Scale up so it renders crisply at any display size
        let scale = size / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.createCGImage(scaled, from: scaled.extent)
    }

    var body: some View {
        if let cg = cgImage {
            Image(decorative: cg, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: size * 0.6))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - QR Code Sheet

/// Full-screen sheet showing a wallet address as a large, shareable QR code.
struct QRCodeSheet: View {
    let address: String
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                // QR code
                QRCodeImage(content: address, size: 240)
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)

                // Address text
                VStack(spacing: 6) {
                    Text("Wallet Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(address)
                        .font(.system(size: 12, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                }

                // Action buttons
                HStack(spacing: 12) {
                    // Copy button
                    Button {
                        copyAddress()
                    } label: {
                        Label(copied ? "Copied!" : "Copy Address",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(copied ? .green : .accentColor)
                    .animation(.easeInOut(duration: 0.2), value: copied)

                    // Share button
                    ShareLink(item: address, subject: Text("My Solana Address")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)

                Text("⚠️ Devnet address — not for real funds")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .navigationTitle("Receive")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func copyAddress() {
#if canImport(UIKit)
        UIPasteboard.general.string = address
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
#endif
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

#Preview {
    QRCodeSheet(address: "7XJBPHKcgTJGMPjxQbT3nbdoUV2LqPxRnwJVDPEqbfvH")
}
