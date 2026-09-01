//
//  MacConversationListView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  1:1 Faithful replication of the Newton Web sidebar with full Light & Dark mode adaptation.
//

import SwiftUI
import AppKit

public struct MacConversationListView: View {
    @Binding public var selectedConversation: Conversation?
    @Binding public var showSettingsSheet: Bool
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText: String = ""
    @State private var hoveredConversationId: String? = nil
    
    public init(selectedConversation: Binding<Conversation?>, showSettingsSheet: Binding<Bool>) {
        self._selectedConversation = selectedConversation
        self._showSettingsSheet = showSettingsSheet
    }
    
    private var isDark: Bool { colorScheme == .dark }
    
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
            // Top Navigation Segmented Pill
            topNavigationPill
            
            // Search Bar Capsule
            searchBar
            
            // New Conversation Dark Pill Button
            newChatButton
            
            // Conversations List
            conversationList
        }
        .frame(width: 260)
        .background(isDark ? Color(red: 0.12, green: 0.15, blue: 0.19) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isDark ? Color(red: 0.20, green: 0.24, blue: 0.30) : Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.04), radius: 10, x: 0, y: 3)
        .padding(.leading, 16)
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private var topNavigationPill: some View {
        HStack(spacing: 6) {
            // Sidebar / List Button
            Button(action: {}) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDark ? Color(red: 0.75, green: 0.80, blue: 0.88) : Color(red: 0.35, green: 0.40, blue: 0.48))
                    .frame(width: 34, height: 32)
            }
            .buttonStyle(.plain)
            
            // Active Chat Tab (Dark Navy / Sand Capsule)
            Button(action: {}) {
                ZStack {
                    Capsule()
                        .fill(isDark ? NewtonTheme.sand : Color(red: 0.06, green: 0.09, blue: 0.16))
                        .frame(width: 52, height: 32)
                    
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 12.5))
                        .foregroundColor(isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : .white)
                }
            }
            .buttonStyle(.plain)
            
            // Settings Gear Button
            Button(action: {
                showSettingsSheet = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(isDark ? Color(red: 0.75, green: 0.80, blue: 0.88) : Color(red: 0.35, green: 0.40, blue: 0.48))
                    .frame(width: 34, height: 32)
            }
            .buttonStyle(.plain)
            .help("Settings & Engine Preferences")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isDark ? Color(red: 0.16, green: 0.20, blue: 0.26) : Color(red: 0.95, green: 0.96, blue: 0.98))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isDark ? Color(red: 0.24, green: 0.28, blue: 0.36) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 0.8)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5))
                .foregroundColor(isDark ? Color(red: 0.55, green: 0.60, blue: 0.68) : Color(red: 0.55, green: 0.60, blue: 0.68))
            
            TextField("Search chats...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(isDark ? .white : Color(red: 0.08, green: 0.11, blue: 0.16))
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.65, green: 0.70, blue: 0.76))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isDark ? Color(red: 0.16, green: 0.20, blue: 0.26) : Color(red: 0.98, green: 0.98, blue: 0.99))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isDark ? Color(red: 0.24, green: 0.28, blue: 0.36) : Color(red: 0.90, green: 0.92, blue: 0.95), lineWidth: 0.8)
        )
        .padding(.horizontal, 14)
    }
    
    @ViewBuilder
    private var newChatButton: some View {
        Button(action: {
            let newConvo = storage.createConversation()
            selectedConversation = newConvo
        }) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 12, weight: .semibold))
                
                Text("New conversation")
                    .font(.system(size: 12.5, weight: .semibold))
                
                Spacer()
            }
            .foregroundColor(isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isDark ? NewtonTheme.sand : Color(red: 0.06, green: 0.09, blue: 0.16))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }
    
    @ViewBuilder
    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredConversations) { convo in
                    conversationRow(convo)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }
    
    @ViewBuilder
    private func conversationRow(_ convo: Conversation) -> some View {
        let isSelected = selectedConversation?.id == convo.id
        let isHovered = hoveredConversationId == convo.id
        
        Button(action: {
            selectedConversation = convo
        }) {
            HStack(spacing: 8) {
                if convo.isGhost {
                    Image(systemName: "ghost.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                } else if convo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                Text(convo.title.isEmpty ? "New Conversation" : convo.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? (isDark ? NewtonTheme.sand : Color(red: 0.06, green: 0.09, blue: 0.16)) : (isDark ? Color(red: 0.78, green: 0.82, blue: 0.88) : Color(red: 0.35, green: 0.40, blue: 0.48)))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                if isHovered || isSelected {
                    Menu {
                        Button(convo.isPinned ? "Unpin" : "Pin to Top") {
                            storage.togglePin(id: convo.id)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            storage.deleteConversation(id: convo.id)
                            if selectedConversation?.id == convo.id {
                                selectedConversation = storage.conversations.first
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11))
                            .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.55, green: 0.60, blue: 0.68))
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? (isDark ? Color(red: 0.18, green: 0.22, blue: 0.28) : Color(red: 0.94, green: 0.96, blue: 0.98)) : (isHovered ? (isDark ? Color(red: 0.15, green: 0.18, blue: 0.24) : Color(red: 0.97, green: 0.98, blue: 0.99)) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredConversationId = hovering ? convo.id : nil
        }
    }
}
