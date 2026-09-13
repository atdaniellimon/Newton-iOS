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
                ChatWrapperView(initialId: convoId)
            }
        }
        .accentColor(NewtonTheme.sand)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onAppear {
            syncService.triggerManualSync()
            if auth.isLoggedIn {
                Task {
                    await storage.syncWithRemoteServer()
                }
                storage.reconnectSyncListenerIfNeeded()
            }
        }
        .onChange(of: auth.isLoggedIn) { loggedIn in
            if !loggedIn {
                navigationPath = NavigationPath()
                selectedConversationId = nil
            } else {
                Task {
                    await storage.syncWithRemoteServer()
                }
                storage.reconnectSyncListenerIfNeeded()
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

public struct ChatWrapperView: View {
    @ObservedObject var storage = StorageManager.shared
    public let initialId: String
    @State private var currentId: String
    
    public init(initialId: String) {
        self.initialId = initialId
        self._currentId = State(initialValue: initialId)
    }
    
    public var body: some View {
        Group {
            if let index = storage.conversations.firstIndex(where: { $0.id == currentId }) {
                ChatView(conversation: $storage.conversations[index])
            } else if let firstMatch = storage.conversations.first {
                // If ID was replaced asynchronously during cloud creation
                ChatView(conversation: $storage.conversations[0])
                    .onAppear {
                        currentId = firstMatch.id
                    }
            } else {
                ZStack {
                    NewtonTheme.bgDark
                        .ignoresSafeArea()
                    Text(L10n.tr("Loading conversation...", es: "Cargando conversación..."))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }
        }
        .onReceive(storage.$conversations) { convos in
            if !convos.contains(where: { $0.id == currentId }), let first = convos.first {
                currentId = first.id
            }
        }
    }
}
