//
//  MacConversationListView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Full-height unified sidebar with native macOS segmented control aligned with window traffic lights.
//

import SwiftUI
import AppKit

public enum SidebarTab: String, CaseIterable, Identifiable {
    case code = "code"
    case chat = "chat"
    case settings = "settings"
    
    public var id: String { rawValue }
}

public struct MacConversationListView: View {
    @Binding public var selectedConversation: Conversation?
    @Binding public var showSettingsSheet: Bool
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedSidebarTab: SidebarTab = .chat
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
            // Top Row: Aligned directly with macOS traffic light buttons
            topHeaderRow
            
            // Search Bar Capsule
            searchBar
            
            // New Conversation Dark Pill Button
            newChatButton
            
            // Conversations List
            conversationList
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(isDark ? Color(red: 0.11, green: 0.14, blue: 0.18) : Color(red: 0.96, green: 0.97, blue: 0.99))
        .overlay(
            Rectangle()
                .fill(isDark ? Color(red: 0.18, green: 0.22, blue: 0.28) : Color(red: 0.88, green: 0.90, blue: 0.94))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    @ViewBuilder
    private var topHeaderRow: some View {
        HStack(spacing: 8) {
            // Space reserved for native macOS window controls (traffic lights)
            Color.clear
                .frame(width: 66, height: 26)
            
            // Native macOS Segmented Control (identical to Settings theme picker)
            Picker("", selection: $selectedSidebarTab) {
                Text("</>")
                    .tag(SidebarTab.code)
                Image(systemName: "bubble.left")
                    .tag(SidebarTab.chat)
                Image(systemName: "gearshape")
                    .tag(SidebarTab.settings)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedSidebarTab) { newTab in
                if newTab == .settings {
                    showSettingsSheet = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedSidebarTab = .chat
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
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
        .background(isDark ? Color(red: 0.15, green: 0.19, blue: 0.25) : Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isDark ? Color(red: 0.22, green: 0.26, blue: 0.34) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 0.8)
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
                    .fill(isSelected ? (isDark ? Color(red: 0.17, green: 0.21, blue: 0.28) : Color(red: 0.90, green: 0.92, blue: 0.96)) : (isHovered ? (isDark ? Color(red: 0.14, green: 0.17, blue: 0.23) : Color(red: 0.94, green: 0.95, blue: 0.98)) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredConversationId = hovering ? convo.id : nil
        }
    }
}
