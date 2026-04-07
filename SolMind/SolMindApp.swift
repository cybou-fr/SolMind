//
//  SolMindApp.swift
//  SolMind
//
//  Created by SAVELIEV Stanislav on 06/04/2026.
//

import SwiftUI

@main
struct SolMindApp: App {
    @State private var walletViewModel = WalletViewModel()
    @State private var chatViewModel = ChatViewModel()
    @State private var confirmationHandler = TransactionConfirmationHandler()
    @State private var statsViewModel = SolanaStatsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(walletViewModel)
                .environment(chatViewModel)
                .environment(confirmationHandler)
                .environment(statsViewModel)
                .task {
                    // Wire AI tools once wallet is available
                    chatViewModel.setupAI(
                        walletManager: walletViewModel.walletManager,
                        confirmationHandler: confirmationHandler,
                        walletViewModel: walletViewModel,
                        statsViewModel: statsViewModel
                    )
                    // Kick off an initial stats + price refresh
                    await statsViewModel.refresh()
                }
        }
#if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
#endif
    }
}
