import SwiftUI

// MARK: - Main Chat View

struct ChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(WalletViewModel.self) private var walletViewModel
    @Environment(TransactionConfirmationHandler.self) private var confirmationHandler
    @Environment(SolanaStatsViewModel.self) private var statsVM

    @State private var showExportSheet = false
    @State private var showMintNFTForm = false

    var body: some View {
        @Bindable var vm = chatViewModel

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // AI Unavailable Banner
                if chatViewModel.aiUnavailable {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text(chatViewModel.aiUnavailableReason)
                            .font(.caption)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                }

                // Context reset notification banner
                if chatViewModel.showContextResetBanner {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Context refreshed — conversation continues in a new session.")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.primary)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Solana live stats bar
                SolanaStatsBar()

                Divider()

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            if chatViewModel.activeConversation?.messages.isEmpty == true {
                                emptyState
                            }
                            ForEach(chatViewModel.activeConversation?.messages ?? []) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            // Spacer anchor — always scroll here
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: chatViewModel.activeConversation?.messages.count) {
                        withAnimation { proxy.scrollTo("bottom") }
                    }
                    .onAppear {
                        proxy.scrollTo("bottom")
                    }
                }

                // Suggestion chips (shown after AI responds, above input bar)
                if !chatViewModel.currentSuggestions.isEmpty && !chatViewModel.isProcessing {
                    suggestionChipsRow(chatViewModel.currentSuggestions)
                }

#if os(macOS) || os(visionOS)
                Divider()
                inputBar(vm: chatViewModel)
#endif
            }
#if os(iOS)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    inputBar(vm: chatViewModel)
                }
                .background(.bar)
            }
#endif
            // Native transaction confirmation card
            .overlay(alignment: .bottom) {
                if let preview = confirmationHandler.pendingPreview {
                    TransactionPreviewCard(
                        preview: preview,
                        onConfirm: { confirmationHandler.confirm() },
                        onCancel: { confirmationHandler.cancel() }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: confirmationHandler.pendingPreview != nil)
            .animation(.spring(duration: 0.4), value: chatViewModel.showContextResetBanner)

            // Success animation overlay (brief checkmark after confirmed tx)
            if chatViewModel.showSuccessAnimation {
                successOverlay
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                DevnetBadge()
            }
            ToolbarItem(placement: .automatic) {
                aiStatsIndicator
            }
            ToolbarItem(placement: .automatic) {
                walletIndicator
            }
            // Conversation export
            ToolbarItem(placement: .automatic) {
                if let convo = chatViewModel.activeConversation, !convo.messages.isEmpty {
                    Menu {
                        ShareLink(
                            item: exportText(convo),
                            preview: SharePreview(convo.title, image: Image(systemName: "text.document"))
                        ) {
                            Label("Export as Text", systemImage: "doc.text")
                        }
                        Button {
                            showExportSheet = true
                        } label: {
                            Label("Export as PDF", systemImage: "doc.richtext")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export conversation")
                    .sheet(isPresented: $showExportSheet) {
                        ExportPDFSheet(conversation: convo)
                    }
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    chatViewModel.newConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Chat (⌘K)")
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .navigationTitle(chatViewModel.activeConversation?.title ?? "SolMind")
#if os(macOS)
        .navigationSubtitle("Devnet")
#endif
        .task {
            await statsVM.refresh()
        }
    }

    // MARK: - Success Animation Overlay

    @ViewBuilder
    private var successOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Transaction sent!")
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 100)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
        .animation(.spring(duration: 0.4), value: chatViewModel.showSuccessAnimation)
        .allowsHitTesting(false)
    }

    // MARK: - Empty State / Demo Walkthrough

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            // Logo
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("SolMind")
                    .font(.title.bold())
                Text("AI-powered Solana wallet assistant")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Wallet status card (shown once wallet is ready)
            if walletViewModel.isWalletReady {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text(walletViewModel.displayAddress)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if walletViewModel.solBalance > 0 {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(walletViewModel.solBalance, format: .number.precision(.fractionLength(4)))
                                .font(.headline.monospacedDigit())
                            Text("SOL")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("0 SOL — ask SolMind for a devnet airdrop!")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            // Feature capability bullets
            VStack(alignment: .leading, spacing: 8) {
                featureRow("drop.fill",        "Request devnet SOL from faucet", .blue)
                featureRow("paperplane.fill",   "Send SOL & SPL tokens",         .purple)
                featureRow("arrow.2.squarepath","Swap tokens via Jupiter DEX",   .green)
                featureRow("photo.artframe",    "Mint compressed NFTs",          .pink)
                featureRow("chart.line.uptrend.xyaxis", "Check live SOL price",  .orange)
                featureRow("doc.text.magnifyingglass",  "Analyze any program address", .teal)
            }
            .padding(.horizontal, 8)

            // Guided demo steps
            VStack(alignment: .leading, spacing: 6) {
                Text("Try these in order:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                let steps: [(String, String)] = [
                    ("1", "What's my SOL balance?"),
                    ("2", "Give me 2 devnet SOL"),
                    ("3", "What's the price of SOL?"),
                    ("4", "Create a token called TestCoin with symbol TCN"),
                    ("5", "Mint me an NFT called SolMind Demo")
                ]
                ForEach(steps, id: \.0) { step in
                    Button {
                        Task {
                            await MainActor.run { chatViewModel.inputText = step.1 }
                            await chatViewModel.sendMessage()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(step.0)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.accentColor, in: Circle())
                            Text(step.1)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func featureRow(_ icon: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Horizontal scrollable suggestion chips
    @ViewBuilder
    private func suggestionChipsRow(_ suggestions: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        Task {
                            await MainActor.run { chatViewModel.inputText = suggestion }
                            await chatViewModel.sendMessage()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .tint(.accentColor)
                    .frame(minHeight: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func inputBar(vm: ChatViewModel) -> some View {
        @Bindable var vm = vm
        HStack(spacing: 8) {
            // Mint NFT compose button
            Button {
                showMintNFTForm = true
            } label: {
                Image(systemName: "photo.artframe")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Mint NFT with custom image & data")
            .sheet(isPresented: $showMintNFTForm) {
                MintNFTFormView(
                    walletAddress: walletViewModel.publicKey ?? "",
                    onSuccess: {},
                    onMinted: { name, symbol, assetId, imageUrl in
                        let explorerURL = SolanaNetwork.explorerURL(address: assetId).absoluteString
                        var msg = "✅ **\(name)** [\(symbol)] minted on devnet!\n"
                        msg += "Asset ID: `\(assetId)`\n"
                        msg += "[View on Explorer](\(explorerURL))"
                        if let img = imageUrl, !img.isEmpty {
                            msg += "\n\n![\(name)](\(img))"
                        }
                        chatViewModel.addSystemMessage(msg)
                    }
                )
            }

            TextField("Ask SolMind anything…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    // Enter sends on all platforms.
                    // On macOS, Shift+Enter / Option+Enter inserts a newline (system default for axis: .vertical).
                    Task { await vm.sendMessage() }
                }

            Button {
                Task { await vm.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .opacity(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing ? 0.35 : 1)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing)
            .accessibilityLabel(vm.isProcessing ? "Sending message" : "Send message")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Toolbar items

    /// AI response time + session stats
    @ViewBuilder
    private var aiStatsIndicator: some View {
        HStack(spacing: 6) {
            if let t = chatViewModel.lastResponseTime {
                HStack(spacing: 3) {
                    Image(systemName: "brain")
                        .font(.caption2)
                    Text("\(t.formatted(.number.precision(.fractionLength(1))))s")
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                .help("Last AI response time")
            }
            if chatViewModel.sessionMessageCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption2)
                    Text("\(chatViewModel.sessionMessageCount)")
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                .help("Messages this session")
            }
            if chatViewModel.sessionTransactionCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("\(chatViewModel.sessionTransactionCount)")
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                .help("Transactions this session")
            }
        }
    }

    @ViewBuilder
    private var walletIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(walletViewModel.isWalletReady ? .green : .gray)
                .frame(width: 6, height: 6)
            Text(walletViewModel.displayAddress)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Conversation Export

    private func exportText(_ convo: Conversation) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        var lines = [
            convo.title,
            "Exported from SolMind — Solana Devnet Wallet",
            "Date: \(df.string(from: convo.createdAt))",
            String(repeating: "-", count: 60),
            ""
        ]
        for msg in convo.messages where !msg.isStreaming {
            let role: String
            switch msg.role {
            case .user: role = "You"
            default:    role = "SolMind"
            }
            lines.append("[\(df.string(from: msg.timestamp))] \(role):")
            lines.append(msg.content)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // Legacy alias kept for any remaining call sites
    private func exportConversation(_ convo: Conversation) -> String { exportText(convo) }
}

// MARK: - PDF Export Sheet

import PDFKit

struct ExportPDFSheet: View {
    let conversation: Conversation
    @Environment(\.dismiss) private var dismiss

    @State private var pdfURL: URL?
    @State private var isGenerating = true

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Generating PDF…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let url = pdfURL {
                    PDFPreviewView(url: url)
                } else {
                    ContentUnavailableView("PDF generation failed", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Export PDF")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let url = pdfURL {
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(
                            item: url,
                            preview: SharePreview(
                                conversation.title,
                                image: Image(systemName: "doc.richtext")
                            )
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .bold()
                    }
                }
            }
        }
        .task {
            pdfURL = await Task.detached(priority: .userInitiated) {
                ExportPDFSheet.renderPDF(conversation: conversation)
            }.value
            isGenerating = false
        }
    }

    // MARK: - PDF Rendering (CoreText + CoreGraphics — all platforms)

    private static func renderPDF(conversation: Conversation) -> URL? {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        let pw: CGFloat = 595.28, ph: CGFloat = 841.89
        var mediaBox = CGRect(x: 0, y: 0, width: pw, height: ph)
        let margin: CGFloat = 50

        let url = tempURL(for: conversation.title)
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, [
            kCGPDFContextCreator: "SolMind",
            kCGPDFContextTitle: conversation.title
        ] as CFDictionary) else { return nil }

        let ctFontKey  = NSAttributedString.Key(kCTFontAttributeName  as String)
        let ctColorKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)

        func attrs(name: String, size: CGFloat, color: CGColor) -> [NSAttributedString.Key: Any] {
            [ctFontKey: CTFontCreateWithName(name as CFString, size, nil), ctColorKey: color]
        }

        let black = CGColor(gray: 0,   alpha: 1)
        let gray  = CGColor(gray: 0.5, alpha: 1)
        let blue  = CGColor(red: 0.2,  green: 0.4,  blue: 0.9,  alpha: 1)
        let green = CGColor(red: 0.1,  green: 0.55, blue: 0.25, alpha: 1)

        let full = NSMutableAttributedString()
        full.append(NSAttributedString(
            string: conversation.title + "\n",
            attributes: attrs(name: "Helvetica-Bold", size: 18, color: black)))
        full.append(NSAttributedString(
            string: "SolMind \u{2014} Solana Devnet  \u{00B7}  \(df.string(from: conversation.createdAt))\n\n",
            attributes: attrs(name: "Helvetica", size: 9, color: gray)))

        for msg in conversation.messages where !msg.isStreaming {
            let isUser: Bool
            switch msg.role { case .user: isUser = true; default: isUser = false }
            let label = isUser ? "You" : "SolMind"
            let lc = isUser ? blue : green
            full.append(NSAttributedString(
                string: "\(label)  \u{00B7}  \(df.string(from: msg.timestamp))\n",
                attributes: attrs(name: "Helvetica-Bold", size: 10, color: lc)))
            let clean = msg.content
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "# ", with: "")
            full.append(NSAttributedString(
                string: clean + "\n\n",
                attributes: attrs(name: "Helvetica", size: 11, color: black)))
        }

        let setter = CTFramesetterCreateWithAttributedString(full)
        let contentRect = CGRect(x: margin, y: margin,
                                 width: pw - margin * 2, height: ph - margin * 2)
        var charIndex = 0
        let totalChars = full.length

        while charIndex < totalChars {
            ctx.beginPDFPage(nil)
            let framePath = CGPath(rect: contentRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                setter, CFRange(location: charIndex, length: 0), framePath, nil)
            CTFrameDraw(frame, ctx)
            let visible = CTFrameGetVisibleStringRange(frame)
            ctx.endPDFPage()
            if visible.length == 0 { break }
            charIndex += visible.length
        }

        ctx.closePDF()
        return url
    }

    private static func tempURL(for title: String) -> URL {
        let safe = title.components(separatedBy: .punctuationCharacters).joined()
            .components(separatedBy: .whitespaces).joined(separator: "_")
        let name = String(safe.prefix(40)) + "-\(Int(Date().timeIntervalSince1970)).pdf"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}

// MARK: - PDF Preview (cross-platform)

#if os(macOS)
struct PDFPreviewView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let v = PDFView(); v.autoScales = true; v.document = PDFDocument(url: url); return v
    }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
#else
struct PDFPreviewView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView(); v.autoScales = true; v.document = PDFDocument(url: url); return v
    }
    func updateUIView(_ v: PDFView, context: Context) {}
}
#endif

// MARK: - Simple Flow Layout (kept for empty state chips fallback)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rowWidth > 0 ? spacing : 0) > width {
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
                rowHeight = max(rowHeight, size.height)
            }
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
    .environment(ChatViewModel())
    .environment(WalletViewModel())
    .environment(SolanaStatsViewModel())
    .environment(TransactionConfirmationHandler())
}
