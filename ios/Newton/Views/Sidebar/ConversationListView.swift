//
//  ConversationListView.swift
//  Newton
//
//  Created for Newton iOS.
//  Native Newton iOS sidebar layout with Chat Pinning, Art Gallery and bottom Settings gear.
//

import SwiftUI

public struct ConversationListView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var cloudService = CloudChatService.shared
    
    @Binding public var selectedConversationId: String?
    public var onSelectConversation: ((String) -> Void)? = nil
    
    public enum FilterTab {
        case all
        case chats
        case remote
    }
    
    @State private var selectedFilterTab: FilterTab = .all
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    @State private var showArtGallery: Bool = false
    @State private var showWorkspaceChooser: Bool = false
    
    public init(selectedConversationId: Binding<String?>, onSelectConversation: ((String) -> Void)? = nil) {
        self._selectedConversationId = selectedConversationId
        self.onSelectConversation = onSelectConversation
    }
    
    private var filteredConversations: [Conversation] {
        var list = storage.conversations
        switch selectedFilterTab {
        case .all:
            break
        case .chats:
            list = list.filter { !$0.isRemoteCodeChat }
        case .remote:
            list = list.filter { $0.isRemoteCodeChat }
        }
        
        if searchText.isEmpty {
            return list
        }
        return list.filter {
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
                // Top Brand Title
                HStack {
                    Text("Newton")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Studio Section Navigation Items (Chats, Ghost, Remote Studio, Art gallery)
                VStack(spacing: 4) {
                    // Host Presence Card Pill
                    HStack(spacing: 8) {
                        Circle()
                            .fill(cloudService.desktopStatus?.online == true ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(cloudService.desktopStatus?.online == true ? "Mac Host Conectado" : "Mac Host Desconectado")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(cloudService.desktopStatus?.online == true ? Color.green : NewtonTheme.textMuted)
                        
                        Spacer()
                        
                        if cloudService.desktopStatus?.online == true {
                            Text("\(cloudService.desktopWorkspaces.count) ws")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(NewtonTheme.surface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 6)
                    
                    // Filter Mode Picker: All Chats vs Remote Studio Code Chats
                    HStack(spacing: 6) {
                        Button {
                            Haptics.selection()
                            selectedFilterTab = .all
                        } label: {
                            Text("All")
                                .font(.system(size: 12, weight: selectedFilterTab == .all ? .semibold : .regular))
                                .foregroundColor(selectedFilterTab == .all ? NewtonTheme.sand : NewtonTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedFilterTab == .all ? NewtonTheme.card : Color.clear)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            Haptics.selection()
                            selectedFilterTab = .chats
                        } label: {
                            Text("Chats")
                                .font(.system(size: 12, weight: selectedFilterTab == .chats ? .semibold : .regular))
                                .foregroundColor(selectedFilterTab == .chats ? NewtonTheme.sand : NewtonTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedFilterTab == .chats ? NewtonTheme.card : Color.clear)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            Haptics.selection()
                            selectedFilterTab = .remote
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 10))
                                Text("Remote Studio")
                            }
                            .font(.system(size: 12, weight: selectedFilterTab == .remote ? .semibold : .regular))
                            .foregroundColor(selectedFilterTab == .remote ? NewtonTheme.sand : NewtonTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedFilterTab == .remote ? NewtonTheme.card : Color.clear)
                            .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 6)
                    
                    Button {
                        Haptics.medium()
                        let ghost = storage.createGhostConversation()
                        selectedConversationId = ghost.id
                        onSelectConversation?(ghost.id)
                    } label: {
                        SidebarItemRow(icon: "ghost", title: "Ghost Session", isSelected: false)
                    }
                    
                    Button {
                        Haptics.light()
                        showArtGallery = true
                    } label: {
                        SidebarItemRow(icon: "cube.transparent", title: "Art gallery", isSelected: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                
                // "Recents" Section Header
                HStack {
                    Text(selectedFilterTab == .remote ? String(localized: "Remote Studio Tasks") : String(localized: "Recents"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(NewtonTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
                
                // Conversations List with Pinning and Deletion
                List {
                    if filteredConversations.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: selectedFilterTab == .remote ? "laptopcomputer" : "bubble.left.and.bubble.right")
                                .font(.system(size: 32))
                                .foregroundColor(NewtonTheme.textMuted.opacity(0.6))
                                .padding(.top, 40)
                            
                            Text(selectedFilterTab == .remote ? String(localized: "No hay tareas de Remote Studio aún") : String(localized: "No hay conversaciones aún"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(NewtonTheme.textSecondary)
                            
                            Text(selectedFilterTab == .remote ? String(localized: "Crea una tarea con '+' para ejecutar código en tu Mac.") : String(localized: "Inicia un nuevo chat con el botón '+'."))
                                .font(.system(size: 13))
                                .foregroundColor(NewtonTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredConversations) { convo in
                            Button(action: {
                                Haptics.selection()
                                selectedConversationId = convo.id
                                onSelectConversation?(convo.id)
                            }) {
                                HStack(spacing: 8) {
                                    if convo.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(NewtonTheme.sand)
                                    }
                                    
                                    if convo.isGhost {
                                        Image(systemName: "ghost.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                                    } else if convo.isRemoteCodeChat {
                                        Image(systemName: "terminal.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(NewtonTheme.sand)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(convo.title)
                                            .font(.system(size: 15, weight: convo.isPinned ? .semibold : .regular))
                                            .foregroundColor(NewtonTheme.textPrimary)
                                            .lineLimit(1)
                                        
                                        if let wsName = convo.workspaceName {
                                            Text(wsName)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(NewtonTheme.textMuted)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading) {
                                Button {
                                    Haptics.light()
                                    storage.togglePin(id: convo.id)
                                } label: {
                                    Label(convo.isPinned ? String(localized: "Unpin") : String(localized: "Pin"), systemImage: convo.isPinned ? "pin.slash.fill" : "pin.fill")
                                }
                                .tint(NewtonTheme.sand)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Haptics.medium()
                                    storage.deleteConversation(id: convo.id)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                            .contextMenu {
                                Button {
                                    Haptics.light()
                                    storage.togglePin(id: convo.id)
                                } label: {
                                    Label(convo.isPinned ? String(localized: "Unpin Chat") : String(localized: "Pin Chat"), systemImage: convo.isPinned ? "pin.slash" : "pin")
                                }
                                
                                Button(role: .destructive) {
                                    Haptics.medium()
                                    storage.deleteConversation(id: convo.id)
                                } label: {
                                    Label("Delete Chat", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await storage.syncWithRemoteServer()
                    await cloudService.refreshHostStatus()
                }
                
                Divider()
                    .background(NewtonTheme.border)
                
                // Bottom Bar: Settings Gear on left + "+ New chat" pill on right
                HStack {
                    // Settings Gear Button
                    Button(action: {
                        showSettings = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(NewtonTheme.surface)
                                .frame(width: 40, height: 40)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 17))
                                .foregroundColor(NewtonTheme.textSecondary)
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
        .sheet(isPresented: $showArtGallery) {
            ArtGalleryView()
        }
        .confirmationDialog(
            "Seleccionar Workspace para Nueva Tarea",
            isPresented: $showWorkspaceChooser,
            titleVisibility: .visible
        ) {
            ForEach(cloudService.desktopWorkspaces) { ws in
                Button(ws.name) {
                    createNewRemoteTask(workspace: ws)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .onAppear {
            Task {
                await storage.syncWithRemoteServer()
                await cloudService.refreshHostStatus()
            }
        }
        .onChange(of: selectedFilterTab) { _ in
            Task {
                await storage.syncWithRemoteServer()
                await cloudService.refreshHostStatus()
            }
        }
        .task {
            // 1. Pull initial state from cloud
            await storage.syncWithRemoteServer()
            await cloudService.refreshHostStatus()
            
            // 2. Start persistent global SSE sync stream
            CloudChatService.shared.startGlobalSyncListener { event in
                storage.handleRemoteSyncEvent(event)
            }
        }
    }
    
    private func createNewChat() {
        Haptics.light()
        if selectedFilterTab == .remote {
            if cloudService.desktopWorkspaces.count > 1 {
                showWorkspaceChooser = true
            } else {
                let firstWs = cloudService.desktopWorkspaces.first
                createNewRemoteTask(workspace: firstWs)
            }
        } else {
            let newConvo = storage.createConversation()
            selectedConversationId = newConvo.id
            onSelectConversation?(newConvo.id)
        }
    }

    private func createNewRemoteTask(workspace: CloudChatService.RemoteWorkspaceItem?) {
        Haptics.medium()
        let taskId = "task_\(Int(Date().timeIntervalSince1970))"
        let remoteConvo = Conversation(
            id: taskId,
            title: "Remote Code Task",
            messages: [],
            isPinned: false,
            isGhost: false,
            modelId: "Singularity-Matrix",
            isRemoteCodeChat: true,
            workspacePath: workspace?.path,
            workspaceName: workspace?.name,
            createdAt: Date(),
            updatedAt: Date()
        )
        storage.conversations.insert(remoteConvo, at: 0)
        storage.sortConversations()
        storage.saveConversations()
        selectedConversationId = remoteConvo.id
        onSelectConversation?(remoteConvo.id)
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
