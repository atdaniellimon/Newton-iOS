//
//  MacConversationListView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacConversationListView: View {
    @Binding public var selectedConversation: Conversation?
    @StateObject private var storage = StorageManager.shared
    @State private var searchText: String = ""
    
    public init(selectedConversation: Binding<Conversation?>) {
        self._selectedConversation = selectedConversation
    }
    
    private var filteredConversations: [Conversation] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return storage.conversations
        } else {
            return storage.conversations.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar with New Chat & Search
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textSecondary)
                    
                    TextField("Search chats...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(NewtonTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                Button(action: createNewChat) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)
                .help("New Conversation (⌘N)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            // Conversation List
            List(selection: $selectedConversation) {
                ForEach(filteredConversations) { conv in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(conv.title.isEmpty ? "New Conversation" : conv.title)
                                .font(.system(size: 13, weight: conv.id == selectedConversation?.id ? .semibold : .regular))
                                .foregroundColor(NewtonTheme.textPrimary)
                                .lineLimit(1)
                            
                            Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .tag(conv)
                    .contextMenu {
                        Button("Delete Conversation", role: .destructive) {
                            storage.deleteConversation(id: conv.id)
                            if selectedConversation?.id == conv.id {
                                selectedConversation = storage.conversations.first
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
    }
    
    private func createNewChat() {
        let newConv = storage.createConversation()
        selectedConversation = newConv
    }
}
