//
//  ConversationListView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct ConversationListView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var settings = SettingsManager.shared
    
    @Binding public var selectedConversationId: String?
    public var onSelectConversation: ((String) -> Void)? = nil
    
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    
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
            NewtonTheme.bgDark
                .ignoresSafeArea()
            
            // Subtle 3D background grid
            Hero3DCanvasView()
                .opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Logo
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text("Newton")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(NewtonTheme.textSecondary)
                            .padding(8)
                            .background(NewtonTheme.surfaceDark)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                // New Chat Button
                Button(action: createNewChat) {
                    HStack {
                        Image(systemName: "plus.bubble.fill")
                            .font(.system(size: 15))
                        Text("New Chat")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "sparkle")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(NewtonTheme.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(NewtonTheme.textSecondary)
                    TextField("Search conversations...", text: $searchText)
                        .foregroundColor(NewtonTheme.textPrimary)
                        .font(.system(size: 14))
                }
                .padding(10)
                .background(NewtonTheme.surfaceDark.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(NewtonTheme.borderDark, lineWidth: 0.8)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Conversations List
                List {
                    ForEach(filteredConversations) { convo in
                        Button(action: {
                            Haptics.selection()
                            selectedConversationId = convo.id
                            onSelectConversation?(convo.id)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: convo.provider.iconName)
                                    .font(.system(size: 15))
                                    .foregroundColor(NewtonTheme.sand)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(convo.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(NewtonTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 4) {
                                        Text(convo.provider.displayName)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(NewtonTheme.textSecondary)
                                        Text("•")
                                            .font(.system(size: 10))
                                            .foregroundColor(NewtonTheme.textMuted)
                                        Text(formatDate(convo.updatedAt))
                                            .font(.system(size: 10))
                                            .foregroundColor(NewtonTheme.textMuted)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(NewtonTheme.textSecondary.opacity(0.5))
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(NewtonTheme.cardDark.opacity(0.85))
                    }
                    .onDelete(perform: storage.deleteConversation)
                }
                .scrollContentBackground(.hidden)
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
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
