//
//  MainView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct MainView: View {
    @ObservedObject var storage = StorageManager.shared
    @State private var selectedConversationId: String? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ConversationListView(selectedConversationId: $selectedConversationId)
        } detail: {
            if let selectedId = selectedConversationId,
               let index = storage.conversations.firstIndex(where: { $0.id == selectedId }) {
                ChatView(conversation: $storage.conversations[index])
            } else if let first = storage.conversations.first,
                      let index = storage.conversations.firstIndex(where: { $0.id == first.id }) {
                ChatView(conversation: $storage.conversations[index])
            } else {
                ZStack {
                    NewtonTheme.bgDark
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundColor(NewtonTheme.sand)
                        Text("No conversation selected")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                }
            }
        }
        .accentColor(NewtonTheme.sand)
        .onAppear {
            if selectedConversationId == nil, let first = storage.conversations.first {
                selectedConversationId = first.id
            }
        }
    }
}
