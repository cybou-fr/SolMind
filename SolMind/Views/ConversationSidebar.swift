import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - macOS / visionOS Conversation Sidebar

struct ConversationSidebar: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(WalletViewModel.self) private var walletViewModel
    @Binding var selectedDestination: AppDestination
    @State private var addressCopied = false

    var body: some View {
        List {
            // Wallet summary card
            Section {
                walletCard
            }

            // App navigation
            Section("Views") {
                navRow(
                    label: "Chat",
                    icon: "bubble.left.and.bubble.right",
                    destination: .chat
                )
                navRow(
                    label: "Portfolio",
                    icon: "chart.pie.fill",
                    destination: .portfolio
                )
                navRow(
                    label: "NFT Gallery",
                    icon: "photo.artframe",
                    destination: .nftGallery
                )
                navRow(
                    label: "Wallets (\(walletViewModel.allAddresses.count))",
                    icon: "wallet.pass",
                    destination: .walletPicker
                )
                navRow(
                    label: "Settings",
                    icon: "gearshape",
                    destination: .settings
                )
            }

            // Conversation history
            Section("Chats") {
                ForEach(chatViewModel.conversations) { convo in
                    conversationRow(convo)
                }
            }
        }
        .navigationTitle("SolMind")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        .toolbar {
            ToolbarItem {
                Button {
                    chatViewModel.newConversation()
                    selectedDestination = .chat
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Chat (⌘N)")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    // MARK: - Clipboard

    private func copyAddress(_ address: String) {
        #if os(iOS)
        UIPasteboard.general.string = address
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        #endif
        withAnimation { addressCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { addressCopied = false }
        }
    }

    // MARK: - Navigation row

    @ViewBuilder
    private func navRow(label: String, icon: String, destination: AppDestination) -> some View {
        Button {
            selectedDestination = destination
        } label: {
            Label(label, systemImage: icon)
                .foregroundStyle(selectedDestination == destination ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .background(
            selectedDestination == destination
                ? Color.accentColor.opacity(0.12)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    // MARK: - Conversation row

    @ViewBuilder
    private func conversationRow(_ convo: Conversation) -> some View {
        Button {
            chatViewModel.activeConversation = convo
            selectedDestination = .chat
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(convo.title)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(convo.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "bubble.left.and.bubble.right")
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .background(
            (chatViewModel.activeConversation?.id == convo.id && selectedDestination == .chat)
                ? Color.accentColor.opacity(0.15)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contextMenu {
            Button(role: .destructive) {
                chatViewModel.deleteConversation(convo)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Wallet card

    @ViewBuilder
    private var walletCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    copyAddress(walletViewModel.publicKey ?? "")
                } label: {
                    HStack(spacing: 4) {
                        Text(walletViewModel.displayAddress)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Image(systemName: addressCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(addressCopied ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(walletViewModel.publicKey == nil)
                .help("Copy wallet address")
                Spacer()
                Circle()
                    .fill(walletViewModel.isWalletReady ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(walletViewModel.solBalance, format: .number.precision(.fractionLength(4)))
                    .font(.title3.bold())
                Text("SOL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let total = walletViewModel.totalPortfolioUSD {
                Text(total, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let solUSD = walletViewModel.solUSDValue {
                Text(solUSD, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Refresh Balance") {
                Task { await walletViewModel.refreshBalance() }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .tint(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationSplitView {
        ConversationSidebar(selectedDestination: .constant(.chat))
    } detail: {
        Text("Select a chat")
    }
    .environment(ChatViewModel())
    .environment(WalletViewModel())
}
