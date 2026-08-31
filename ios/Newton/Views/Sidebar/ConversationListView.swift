//
//  ConversationListView.swift
//  Newton
//
//  Created for Newton iOS.
//  Matching Claude iOS sidebar layout.
//

import SwiftUI

public struct ConversationListView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var settings = SettingsManager.shared
    
    @Binding public var selectedConversationId: String?
    public var onSelectConversation: ((String) -> Void)? = nil
    
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    @State private var conversationToDelete: Conversation? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    public init(selectedConversationId: Binding<String?>, onSelectConversation: ((String) -> Void)? = nil) {
        self._selectedConversationId = selectedConversationId
        self.onSelectConversation = onSelectConversation
    }
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return storage.conversations
        }
        return storage.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.messages.contains(where: { $0.content.localizedCaseInsensitiveContains(searchText) })
        }
    }
    
    public var body: some View {
        ZStack {
            NewtonTheme.bg
                .ignoresSafeArea()
            
            // 3D background wave grid
            Hero3DCanvasView()
                .opacity(0.35)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Top Brand Title (No bulb icon, clean serif "Newton")
                HStack {
                    Text("Newton")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(NewtonTheme.textSecondary)
                            .padding(8)
                            .background(NewtonTheme.surface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 18)
                
                // Studio Section Navigation Items (Chats, Projects, Code, Artifacts)
                VStack(spacing: 4) {
                    SidebarItemRow(icon: "bubble.left.and.bubble.right", title: "Chats", isSelected: true)
                    SidebarItemRow(icon: "folder", title: "Projects", isSelected: false)
                    SidebarItemRow(icon: "chevron.left.forwardslash.chevron.right", title: "Code", isSelected: false)
                    SidebarItemRow(icon: "cube.transparent", title: "Artifacts", isSelected: false)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
                // "Recents" Section Header
                HStack {
                    Text("Recents")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(NewtonTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
                
                // Conversations List with Swipe to Delete and Clean Typography
                List {
                    ForEach(filteredConversations) { convo in
                        Button(action: {
                            Haptics.selection()
                            selectedConversationId = convo.id
                            onSelectConversation?(convo.id)
                        }) {
                            HStack {
                                Text(convo.title)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Haptics.medium()
                                storage.deleteConversation(id: convo.id)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                Haptics.medium()
                                storage.deleteConversation(id: convo.id)
                            } label: {
                                Label("Delete Chat", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                Divider()
                    .background(NewtonTheme.border)
                
                // Bottom Bar matching screenshot (User Avatar D on left + Floating "+ New chat" pill on right)
                HStack {
                    // User Avatar with Initial "D"
                    Button(action: {
                        showSettings = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(NewtonTheme.surface)
                                .frame(width: 38, height: 38)
                            Text("D")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(NewtonTheme.textPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    // "+ New chat" pill button
                    Button(action: createNewChat) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("New chat")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(NewtonTheme.bg)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private func createNewChat() {
        Haptics.light()
        let newConvo = storage.createConversation(
            provider: settings.currentProvider,
            modelId: settings.currentModelId
        )
        selectedConversationId = newConvo.id
        onSelectConversation?(newConvo.id)
    }
}

public struct SidebarItemRow: View {
    public let icon: String
    public let title: String
    public let isSelected: Bool
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(isSelected ? NewtonTheme.sand : NewtonTheme.textSecondary)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? NewtonTheme.textPrimary : NewtonTheme.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? NewtonTheme.card.opacity(0.7) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
