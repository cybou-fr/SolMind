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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(walletViewModel)
                .environment(chatViewModel)
        }
#if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
#endif
    }
}
