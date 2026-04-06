//
//  ContentView.swift
//  SolMind
//
//  Created by SAVELIEV Stanislav on 06/04/2026.
//

import SwiftUI

// MARK: - App destination for sidebar navigation
enum AppDestination: Hashable {
    case chat
    case portfolio
    case nftGallery
    case walletPicker
}

struct ContentView: View {
    @Environment(WalletViewModel.self) private var walletViewModel
    @Environment(ChatViewModel.self) private var chatViewModel

    @State private var selectedDestination: AppDestination = .chat

    var body: some View {
        Group {
            if !walletViewModel.isWalletReady {
                WalletSetupView()
            } else {
#if os(visionOS)
                NavigationSplitView {
                    ConversationSidebar(selectedDestination: $selectedDestination)
                } detail: {
                    detailView
                }
                .ornament(attachmentAnchor: .scene(.leading)) {
                    PortfolioOrnamentView()
                        .glassBackgroundEffect()
                }
#elseif os(macOS)
                NavigationSplitView {
                    ConversationSidebar(selectedDestination: $selectedDestination)
                } detail: {
                    detailView
                }
#else
                // iOS / iPadOS
                TabView {
                    NavigationStack {
                        ChatView()
                            .navigationTitle("SolMind")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

                    NavigationStack {
                        PortfolioView()
                    }
                    .tabItem { Label("Portfolio", systemImage: "chart.pie") }

                    NavigationStack {
                        NFTGalleryView()
                    }
                    .tabItem { Label("NFTs", systemImage: "photo.artframe") }

                    NavigationStack {
                        WalletPickerView()
                    }
                    .tabItem { Label("Wallets", systemImage: "wallet.pass") }
                }
#endif
            }
        }
        .task {
            await walletViewModel.setup()
        }
    }

    // MARK: - macOS / visionOS Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedDestination {
        case .chat:
            ChatView()
        case .portfolio:
            PortfolioView()
        case .nftGallery:
            NFTGalleryView()
        case .walletPicker:
            WalletPickerView()
        }
    }
}

#Preview {
    ContentView()
        .environment(WalletViewModel())
        .environment(ChatViewModel())
}
