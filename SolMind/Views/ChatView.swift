import SwiftUI

// MARK: - Main Chat View

struct ChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(WalletViewModel.self) private var walletViewModel
    @Environment(TransactionConfirmationHandler.self) private var confirmationHandler
    @Environment(SolanaStatsViewModel.self) private var statsVM

    var body: some View {
        @Bindable var vm = chatViewModel

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // AI Unavailable Banner
                if chatViewModel.aiUnavailable {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("Apple Intelligence unavailable. Enable it in System Settings.")
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
                    ShareLink(item: exportConversation(convo)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export conversation")
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
            TextField("Ask SolMind anything…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                .onSubmit {
#if os(macOS)
                    // ⌘Enter sends on macOS
#else
                    Task { await vm.sendMessage() }
#endif
                }

            Button {
                Task { await vm.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing)
            .keyboardShortcut(.return, modifiers: .command)
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

    private func exportConversation(_ convo: Conversation) -> String {
        var lines = ["# \(convo.title)", "Exported from SolMind (Devnet)", ""]
        for msg in convo.messages where !msg.isStreaming {
            let role: String
            switch msg.role {
            case .user: role = "You"
            default:    role = "SolMind"
            }
            lines.append("**\(role):** \(msg.content)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

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
