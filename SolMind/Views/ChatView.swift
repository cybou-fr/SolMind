import SwiftUI

// MARK: - Main Chat View

struct ChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(WalletViewModel.self) private var walletViewModel
    @Environment(TransactionConfirmationHandler.self) private var confirmationHandler
    @Environment(SolanaStatsViewModel.self) private var statsVM

    var body: some View {
        @Bindable var vm = chatViewModel

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

    // MARK: - Sub-views

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("SolMind")
                .font(.title2.bold())
            Text("Your AI-powered Solana wallet assistant.\nAll transactions are on **devnet** — test money only.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Static starter suggestions
            let starters = [
                "What's my balance?",
                "Give me some devnet SOL",
                "What's the price of SOL?",
                "Show my recent transactions"
            ]
            suggestionChipsRow(starters)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
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

    /// AI response time badge
    @ViewBuilder
    private var aiStatsIndicator: some View {
        if let t = chatViewModel.lastResponseTime {
            HStack(spacing: 3) {
                Image(systemName: "brain")
                    .font(.caption2)
                Text(String(format: "%.1fs", t))
                    .font(.caption2.monospacedDigit())
            }
            .foregroundStyle(.secondary)
            .help("Last AI response time")
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
