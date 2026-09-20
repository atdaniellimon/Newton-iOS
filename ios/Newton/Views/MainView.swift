//
//  MainView.swift
//  Newton
//
//  Created for Newton iOS.
//  Configured with Navigation, Deep Links, and iCloud Auto-Sync.
//

import SwiftUI

public struct MainView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var syncService = iCloudSyncService.shared
    @ObservedObject var auth = AuthManager.shared

    @State private var navigationPath = NavigationPath()
    @State private var selectedConversationId: String? = nil

    public init() {}

    public var body: some View {
        // Gate: show AuthView if not logged in
        if !auth.isLoggedIn {
            AuthView()
        } else {
        NavigationStack(path: $navigationPath) {
            ConversationListView(
                selectedConversationId: $selectedConversationId,
                onSelectConversation: { convoId in
                    navigationPath.append(convoId)
                }
            )
            .navigationDestination(for: String.self) { convoId in
                if let index = storage.conversations.firstIndex(where: { $0.id == convoId }) {
                    ChatView(conversation: $storage.conversations[index])
                } else {
                    ZStack {
                        NewtonTheme.bgDark
                            .ignoresSafeArea()
                        Text("Conversation not found")
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                }
            }
        }
        .accentColor(NewtonTheme.sand)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onAppear {
            syncService.triggerManualSync()
        }
        .onChange(of: auth.isLoggedIn) { loggedIn in
            if !loggedIn {
                navigationPath = NavigationPath()
                selectedConversationId = nil
            }
        }
        } // end auth.isLoggedIn
    }

    private func handleDeepLink(_ url: URL) {
        let host = url.host?.lowercased() ?? url.path.lowercased().replacingOccurrences(of: "/", with: "")
        
        if host == "ghost" {
            let ghost = storage.createGhostConversation()
            navigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationPath.append(ghost.id)
            }
        } else if host == "new" {
            let newConvo = storage.createConversation()
            navigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationPath.append(newConvo.id)
            }
        } else if host == "voice" {
            let newConvo = storage.createConversation(title: "Voice Session")
            navigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationPath.append(newConvo.id)
            }
        }
    }
}
