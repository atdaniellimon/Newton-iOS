//
//  MainMacSplitView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MainMacSplitView: View {
    @StateObject private var storage = StorageManager.shared
    @State private var selectedConversation: Conversation? = nil
    
    public var body: some View {
        NavigationView {
            MacConversationListView(selectedConversation: $selectedConversation)
            
            if let selected = bindingForSelectedConversation() {
                MacChatView(conversation: selected)
            } else {
                VStack(spacing: 16) {
                    MacHero3DCanvasView()
                        .frame(width: 260, height: 260)
                    
                    Text("Newton AI")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Text("Select a conversation from the sidebar or press ⌘N to begin.")
                        .font(.system(size: 13))
                        .foregroundColor(NewtonTheme.textSecondary)
                    
                    Button("Start New Conversation") {
                        let newConv = storage.createConversation()
                        selectedConversation = newConv
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NewtonTheme.sand)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(NewtonTheme.background)
            }
        }
        .onAppear {
            if selectedConversation == nil {
                selectedConversation = storage.conversations.first ?? storage.createConversation()
            }
        }
    }
    
    private func bindingForSelectedConversation() -> Binding<Conversation>? {
        guard let sel = selectedConversation,
              let idx = storage.conversations.firstIndex(where: { $0.id == sel.id }) else {
            return nil
        }
        return $storage.conversations[idx]
    }
}
