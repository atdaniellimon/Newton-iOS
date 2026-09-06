//
//  MacConversationListView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Full-height unified sidebar supporting both Chat and Newton Code Project modes.
//

import SwiftUI
import AppKit

public enum SidebarTab: String, CaseIterable, Identifiable {
    case chat = "chat"
    case code = "code"
    
    public var id: String { rawValue }
}

public struct MacConversationListView: View {
    @Binding public var selectedConversation: Conversation?
    @Binding public var selectedSidebarTab: SidebarTab
    
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    @ObservedObject private var workspace = NewtonCodeWorkspaceManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText: String = ""
    @State private var hoveredConversationId: String? = nil
    
    public init(
        selectedConversation: Binding<Conversation?>,
        selectedSidebarTab: Binding<SidebarTab>
    ) {
        self._selectedConversation = selectedConversation
        self._selectedSidebarTab = selectedSidebarTab
    }
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var filteredConversations: [Conversation] {
        let generalChats = storage.conversations.filter { $0.workspacePath == nil }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return generalChats
        } else {
            return generalChats.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            // Top Row: Aligned directly with macOS traffic light buttons at the very top
            topHeaderRow
            
            if selectedSidebarTab == .code {
                // Newton Code Mode Sidebar
                codeSidebarContent
            } else {
                // Regular Chat Mode Sidebar
                chatSidebarContent
            }
        }
        .padding(.top, 0)
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(isDark ? Color(red: 0.10, green: 0.12, blue: 0.16) : Color(red: 0.96, green: 0.97, blue: 0.99))
        .overlay(
            Rectangle()
                .fill(isDark ? Color(red: 0.18, green: 0.22, blue: 0.28) : Color(red: 0.88, green: 0.90, blue: 0.94))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    // MARK: - Top Header Row (Aligned with macOS Traffic Lights)
    @ViewBuilder
    private var topHeaderRow: some View {
        HStack(spacing: 6) {
            Color.clear
                .frame(width: 68, height: 28)
            
            Picker("", selection: $selectedSidebarTab) {
                Image(systemName: "bubble.left.fill")
                    .tag(SidebarTab.chat)
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .tag(SidebarTab.code)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: selectedSidebarTab) { newTab in
                if newTab == .code {
                    selectedConversation = nil
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
    }
    
    // MARK: - Chat Mode Sidebar Content
    @ViewBuilder
    private var chatSidebarContent: some View {
        VStack(spacing: 10) {
            // Search Bar Capsule
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(red: 0.55, green: 0.60, blue: 0.68))
                
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
            .padding(.vertical, 7)
            .background(isDark ? Color(red: 0.15, green: 0.18, blue: 0.24) : Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isDark ? Color(red: 0.22, green: 0.26, blue: 0.34) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 0.8)
            )
            .padding(.horizontal, 14)
            
            // New Conversation Button
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
                .padding(.vertical, 9)
                .background(isDark ? NewtonTheme.sand : Color(red: 0.06, green: 0.09, blue: 0.16))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            
            // Conversation Rows
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredConversations) { convo in
                        conversationRow(convo)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Newton Code Mode Sidebar Content (Matching Claude Code)
    @ViewBuilder
    private var codeSidebarContent: some View {
        VStack(spacing: 8) {
            // Action Buttons: + New & Customize
            HStack(spacing: 8) {
                Button(action: {
                    var newConvo = storage.createConversation()
                    newConvo.workspacePath = workspace.activeWorkspacePath
                    newConvo.title = "Task in \(workspace.activeProjectName)"
                    storage.updateConversation(newConvo)
                    selectedConversation = newConvo
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("New")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isDark ? Color(red: 0.90, green: 0.93, blue: 0.98) : Color(red: 0.12, green: 0.15, blue: 0.20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.26) : Color(red: 0.90, green: 0.92, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    workspace.selectWorkspaceDirectory()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11))
                        Text("Workspace")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isDark ? Color(red: 0.90, green: 0.93, blue: 0.98) : Color(red: 0.12, green: 0.15, blue: 0.20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.26) : Color(red: 0.90, green: 0.92, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Add New Project Directory")
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            
            // Projects List with Grouped Tasks
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(workspace.projects) { proj in
                        projectSectionView(proj: proj)
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Bottom Profile Badge (daniel · Gateway)
            HStack(spacing: 8) {
                Text("✴")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(NewtonTheme.sand)
                
                Text("daniel · Gateway")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(isDark ? Color(red: 0.85, green: 0.88, blue: 0.94) : Color(red: 0.20, green: 0.25, blue: 0.32))
                
                Spacer()
                
                Circle()
                    .fill(NewtonTheme.forestGreen)
                    .frame(width: 5.5, height: 5.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    @ViewBuilder
    private func projectSectionView(proj: CodeProject) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Project Header
            HStack {
                Text(proj.name)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.40, green: 0.45, blue: 0.52))
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    workspace.activeWorkspacePath = proj.path
                    workspace.activeProjectName = proj.name
                    var newConvo = storage.createConversation()
                    newConvo.workspacePath = proj.path
                    newConvo.title = "Task in \(proj.name)"
                    storage.updateConversation(newConvo)
                    selectedConversation = newConvo
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isDark ? Color(red: 0.60, green: 0.65, blue: 0.72) : Color(red: 0.50, green: 0.55, blue: 0.62))
                }
                .buttonStyle(.plain)
                .help("New Task in \(proj.name)")
            }
            .padding(.horizontal, 14)
            
            // Specific Project Tasks only
            let projectTasks = storage.conversations.filter { $0.workspacePath == proj.path || $0.workspacePath == proj.name }
            if projectTasks.isEmpty {
                Text("No tasks yet")
                    .font(.system(size: 11))
                    .foregroundColor(isDark ? Color(red: 0.45, green: 0.50, blue: 0.58) : Color.gray)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 2)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(projectTasks) { convo in
                        projectTaskButton(convo: convo, proj: proj)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
    }
    
    @ViewBuilder
    private func projectTaskButton(convo: Conversation, proj: CodeProject) -> some View {
        Button(action: {
            workspace.activeWorkspacePath = proj.path
            workspace.activeProjectName = proj.name
            selectedConversation = convo
        }) {
            HStack(spacing: 6) {
                Circle()
                    .stroke(isDark ? Color(red: 0.45, green: 0.50, blue: 0.58) : Color(red: 0.65, green: 0.70, blue: 0.76), lineWidth: 1)
                    .frame(width: 5, height: 5)
                
                Text(convo.title.isEmpty ? "Task" : convo.title)
                    .font(.system(size: 12))
                    .foregroundColor(selectedConversation?.id == convo.id ? (isDark ? NewtonTheme.sand : Color.black) : (isDark ? Color(red: 0.80, green: 0.84, blue: 0.90) : Color(red: 0.30, green: 0.35, blue: 0.42)))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(selectedConversation?.id == convo.id ? (isDark ? Color(red: 0.16, green: 0.20, blue: 0.27) : Color(red: 0.90, green: 0.92, blue: 0.96)) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: {
                if selectedConversation?.id == convo.id {
                    selectedConversation = nil
                }
                storage.deleteConversation(id: convo.id)
            }) {
                Label("Delete Task", systemImage: "trash")
            }
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
