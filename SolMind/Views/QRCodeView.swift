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
/// Supports Solana Pay request URLs (solana:<address>?amount=<amount>) via an optional amount field.
struct QRCodeSheet: View {
    let address: String
    @State private var copied = false
    @State private var amountText = ""
    @State private var showPayMode = false
    @Environment(\.dismiss) private var dismiss

    /// The content encoded in the QR: plain address, or a Solana Pay URL when an amount is set.
    private var qrContent: String {
        guard showPayMode,
              let amount = Double(amountText), amount > 0 else {
            return address
        }
        return "solana:\(address)?amount=\(amount)&label=SolMind&network=devnet"
    }

    private var shareLabel: String {
        showPayMode && !amountText.isEmpty ? "Share Payment Request" : "Share Address"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Mode toggle
                Picker("Mode", selection: $showPayMode) {
                    Text("Receive").tag(false)
                    Text("Request Payment").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)

                // Amount field (Solana Pay mode)
                if showPayMode {
                    HStack {
                        Text("Amount (SOL)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0.00", text: $amountText)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 15, design: .monospaced))
                            .frame(width: 100)
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // QR code
                QRCodeImage(content: qrContent, size: 240)
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                    .animation(.spring(response: 0.3), value: qrContent)

                // Address / URL label
                VStack(spacing: 4) {
                    if showPayMode && !amountText.isEmpty, Double(amountText) != nil {
                        Text("Solana Pay Request")
                            .font(.caption.bold())
                            .foregroundStyle(.tint)
                        Text("\(amountText) SOL → \(address.prefix(8))…\(address.suffix(8))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Wallet Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(address)
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 20)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        copyContent()
                    } label: {
                        Label(copied ? "Copied!" : "Copy",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(copied ? .green : .accentColor)
                    .animation(.easeInOut(duration: 0.2), value: copied)

                    ShareLink(item: qrContent, subject: Text(shareLabel)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)

                Text("⚠️ Devnet — not for real funds")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .animation(.easeInOut(duration: 0.25), value: showPayMode)
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

    private func copyContent() {
#if canImport(UIKit)
        UIPasteboard.general.string = qrContent
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(qrContent, forType: .string)
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
