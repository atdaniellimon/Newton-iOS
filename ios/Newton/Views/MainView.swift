//
//  MainView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct MainView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @State private var navigationPath = NavigationPath()
    @State private var selectedConversationId: String? = nil
    
    public init() {}
    
    public var body: some View {
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
    }
}
