//
//  ContentView.swift
//  SolMind
//
//  Created by SAVELIEV Stanislav on 06/04/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @Environment(ChatViewModel.self) private var chatViewModel

    @State private var showWalletSetup = false

    var body: some View {
        Group {
            if !walletViewModel.isWalletReady {
                WalletSetupView()
            } else {
#if os(macOS)
                NavigationSplitView {
                    ConversationSidebar()
                } detail: {
                    ChatView()
                }
                .navigationTitle("SolMind")
#else
                NavigationStack {
                    ChatView()
                        .navigationTitle("SolMind")
                        .navigationBarTitleDisplayMode(.inline)
                }
#endif
            }
        }
        .task {
            await walletViewModel.setup()
        }
    }
}

#Preview {
    ContentView()
        .environment(WalletViewModel())
        .environment(ChatViewModel())
}
