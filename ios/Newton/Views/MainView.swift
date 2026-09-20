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
            .navigationDestination(for: String.self) { targetId in
                if targetId.hasPrefix("remote:") {
                    RemoteChatRouteView(routeString: targetId)
                } else {
                    ChatWrapperView(initialId: targetId)
                }
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
            } else if let index = storage.conversations.firstIndex(where: { $0.id == initialId }) {
                ChatView(conversation: $storage.conversations[index])
                    .onAppear {
                        currentId = initialId
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
    }
}


public struct RemoteChatRouteView: View {
    public let routeString: String
    
    // Format: "remote:<encodedWsPath>:<chatId>" or "remote:<encodedWsPath>" or "remote:new"
    public var body: some View {
        let parts = routeString.components(separatedBy: ":")
        let wsPath = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : nil
        let chatId = parts.count > 2 ? parts[2] : nil
        
        let wsItem = wsPath != nil && !wsPath!.isEmpty ? CloudChatService.RemoteWorkspaceItem(
            name: (wsPath! as NSString).lastPathComponent,
            path: wsPath!,
            hasGit: nil,
            branch: nil,
            chats: nil
        ) : nil
        
        let chatItem = chatId != nil && !chatId!.isEmpty ? CloudChatService.RemoteWorkspaceChat(
            id: chatId!,
            title: L10n.tr("Remote Task", es: "Tarea Remota"),
            created_at: nil,
            messages: nil
        ) : nil
        
        DesktopRemoteControlView(
            initialWorkspace: wsItem,
            initialChat: chatItem
        )
    }
}
