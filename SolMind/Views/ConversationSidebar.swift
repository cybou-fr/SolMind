import SwiftUI

// MARK: - macOS Conversation Sidebar

struct ConversationSidebar: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(WalletViewModel.self) private var walletViewModel

    var body: some View {
        List {
            Section {
                walletCard
            }
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
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Chat")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private func conversationRow(_ convo: Conversation) -> some View {
        Button {
            chatViewModel.activeConversation = convo
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
            chatViewModel.activeConversation?.id == convo.id
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

    @ViewBuilder
    private var walletCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(walletViewModel.displayAddress)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(walletViewModel.isWalletReady ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.4f", walletViewModel.solBalance))
                    .font(.title3.bold())
                Text("SOL")
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
        ConversationSidebar()
    } detail: {
        Text("Select a chat")
    }
    .environment(ChatViewModel())
    .environment(WalletViewModel())
}
