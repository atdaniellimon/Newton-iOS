//
//  MainMacSplitView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Matches the web desktop layout.
//

import SwiftUI
import AppKit

public struct MainMacSplitView: View {
    @StateObject private var storage = StorageManager.shared
    @State private var selectedConversation: Conversation? = nil
    @State private var showSettingsSheet: Bool = false
    
    public var body: some View {
        HStack(spacing: 0) {
            // Floating Sidebar Card
            MacConversationListView(
                selectedConversation: $selectedConversation,
                showSettingsSheet: $showSettingsSheet
            )
            
            // Main Chat Canvas Area
            if let selected = bindingForSelectedConversation() {
                MacChatView(conversation: selected)
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            }
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .onAppear {
            if selectedConversation == nil {
                selectedConversation = storage.conversations.first ?? storage.createConversation()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            MacSettingsView()
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
