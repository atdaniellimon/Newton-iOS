//
//  MacConversationListView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Matches the web desktop floating sidebar card.
//

import SwiftUI
import AppKit

public struct MacConversationListView: View {
    @Binding public var selectedConversation: Conversation?
    @Binding public var showSettingsSheet: Bool
    @StateObject private var storage = StorageManager.shared
    @State private var searchText: String = ""
    
    public init(selectedConversation: Binding<Conversation?>, showSettingsSheet: Binding<Bool>) {
        self._selectedConversation = selectedConversation
        self._showSettingsSheet = showSettingsSheet
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
        VStack(spacing: 12) {
            topNavigationPill
            searchBar
            newChatButton
            conversationList
        }
        .frame(width: 240)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .padding(.leading, 12)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var topNavigationPill: some View {
        HStack(spacing: 8) {
            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.30, blue: 0.38))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            
            Button(action: {}) {
                ZStack {
                    Capsule()
                        .fill(Color(red: 0.06, green: 0.09, blue: 0.16))
                        .frame(width: 44, height: 32)
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            
            Button(action: {
                let ghost = storage.createGhostConversation()
                selectedConversation = ghost
            }) {
                Image(systemName: "ghost")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Start ephemeral Ghost Session (no history saved)")
            
            Button(action: {
                showSettingsSheet = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.30, blue: 0.38))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Settings & API Keys")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(red: 0.95, green: 0.96, blue: 0.98))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.55, green: 0.60, blue: 0.68))
            
            TextField("Search chats...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }
    
    @ViewBuilder
    private var newChatButton: some View {
        Button(action: createNewChat) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 12))
                
                Text("New conversation")
                    .font(.system(size: 12.5, weight: .semibold))
                
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(red: 0.06, green: 0.09, blue: 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
    }
    
    @ViewBuilder
    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredConversations) { conv in
                    MacConversationRowView(
                        conversation: conv,
                        isSelected: conv.id == selectedConversation?.id,
                        onSelect: {
                            selectedConversation = conv
                        },
                        onDelete: {
                            storage.deleteConversation(id: conv.id)
                            if selectedConversation?.id == conv.id {
                                selectedConversation = storage.conversations.first
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
    
    private func createNewChat() {
        let newConv = storage.createConversation()
        selectedConversation = newConv
    }
}

public struct MacConversationRowView: View {
    public let conversation: Conversation
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onDelete: () -> Void
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                if conversation.isGhost {
                    Image(systemName: "ghost.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                }
                
                Text(conversation.title.isEmpty ? "New Conversation" : conversation.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(red: 0.06, green: 0.09, blue: 0.16) : Color(red: 0.25, green: 0.30, blue: 0.38))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
