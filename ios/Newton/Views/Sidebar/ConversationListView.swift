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
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    
    public init(selectedConversationId: Binding<String?>) {
        self._selectedConversationId = selectedConversationId
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
            
            VStack(spacing: 0) {
                // New Chat Button
                Button(action: createNewChat) {
                    HStack {
                        Image(systemName: "plus.bubble.fill")
                            .font(.system(size: 15))
                        Text("New Chat")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(NewtonTheme.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(NewtonTheme.textSecondary)
                    TextField("Search conversations...", text: $searchText)
                        .foregroundColor(NewtonTheme.textPrimary)
                        .font(.system(size: 14))
                }
                .padding(10)
                .background(NewtonTheme.surfaceDark)
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
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: convo.provider.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedConversationId == convo.id ? NewtonTheme.sand : NewtonTheme.textSecondary)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(convo.title)
                                        .font(.system(size: 14, weight: selectedConversationId == convo.id ? .semibold : .regular))
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
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(selectedConversationId == convo.id ? NewtonTheme.surfaceDark : NewtonTheme.cardDark)
                    }
                    .onDelete(perform: storage.deleteConversation)
                }
                .scrollContentBackground(.hidden)
                
                Divider()
                    .background(NewtonTheme.borderDark)
                
                // Bottom Settings Shortcut
                HStack {
                    Button(action: {
                        showSettings = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(NewtonTheme.textSecondary)
                            Text("Settings")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(NewtonTheme.textPrimary)
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(NewtonTheme.cardDark)
            }
        }
        .navigationTitle("Newton")
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
