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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(walletViewModel)
                .environment(chatViewModel)
                .environment(confirmationHandler)
                .task {
                    // Wire AI tools once wallet is available
                    chatViewModel.setupAI(
                        walletManager: walletViewModel.walletManager,
                        confirmationHandler: confirmationHandler
                    )
                }
        }
#if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
#endif
    }
}
