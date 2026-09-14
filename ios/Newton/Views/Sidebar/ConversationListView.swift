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
    @ObservedObject var loc = LocalizationManager.shared
    
    @Binding public var selectedConversationId: String?
    public var onSelectConversation: ((String) -> Void)? = nil
    
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    @State private var showArtGallery: Bool = false
    @State private var showWorkspaces: Bool = false
    @State private var showDesktopRemote: Bool = false
    
    // View Mode: .chats vs .remoteStudio
    public enum SidebarMode {
        case chats
        case remoteStudio
    }
    @State private var currentMode: SidebarMode = .chats
    
    // Remote Studio State
    @State private var remoteWorkspaces: [CloudChatService.RemoteWorkspaceItem] = []
    @State private var remoteStatus: CloudChatService.RemoteDesktopStatus? = nil
    @State private var isFetchingRemote: Bool = false
    @State private var expandedWorkspacePaths: Set<String> = []
    
    // Target workspace & chat when opening DesktopRemoteControlView
    @State private var activeRemoteWorkspace: CloudChatService.RemoteWorkspaceItem? = nil
    @State private var activeRemoteChat: CloudChatService.RemoteWorkspaceChat? = nil
    
    public init(selectedConversationId: Binding<String?>, onSelectConversation: ((String) -> Void)? = nil) {
        self._selectedConversationId = selectedConversationId
        self.onSelectConversation = onSelectConversation
    }
    
    private var filteredConversations: [Conversation] {
        let list = storage.conversations
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
                .padding(.bottom, 12)
                
                // Studio Section Navigation Items (Chats, Ghost, Remote Studio, Workspaces, Art gallery)
                VStack(spacing: 4) {
                    Button {
                        Haptics.light()
                        currentMode = .chats
                    } label: {
                        SidebarItemRow(icon: "bubble.left.and.bubble.right", title: L10n.tr("Chats", es: "Chats"), isSelected: currentMode == .chats)
                    }
                    
                    Button {
                        Haptics.light()
                        currentMode = .remoteStudio
                        loadRemoteStudioData()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "macbook.and.iphone")
                                .font(.system(size: 15))
                                .foregroundColor(currentMode == .remoteStudio ? NewtonTheme.sand : NewtonTheme.textSecondary)
                                .frame(width: 24)
                            
                            Text(L10n.tr("Remote Studio", es: "Remote Studio"))
                                .font(.system(size: 15, weight: currentMode == .remoteStudio ? .semibold : .regular))
                                .foregroundColor(currentMode == .remoteStudio ? NewtonTheme.textPrimary : NewtonTheme.textSecondary)
                            
                            Spacer()
                            
                            Circle()
                                .fill(remoteStatus?.online == true ? Color.green : Color.red)
                                .frame(width: 7, height: 7)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(currentMode == .remoteStudio ? NewtonTheme.card.opacity(0.7) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    Button {
                        Haptics.medium()
                        let ghost = storage.createGhostConversation(title: L10n.tr("Ghost Session", es: "Sesión Fantasma"))
                        selectedConversationId = ghost.id
                        onSelectConversation?(ghost.id)
                    } label: {
                        SidebarItemRow(icon: "ghost", title: L10n.tr("Ghost Session", es: "Sesión Fantasma"), isSelected: false)
                    }
                    
                    Button {
                        Haptics.light()
                        showWorkspaces = true
                    } label: {
                        SidebarItemRow(icon: "folder.fill", title: L10n.tr("Workspaces", es: "Espacios de trabajo"), isSelected: false)
                    }
                    
                    Button {
                        Haptics.light()
                        showArtGallery = true
                    } label: {
                        SidebarItemRow(icon: "cube.transparent", title: L10n.tr("Art gallery", es: "Galería de arte"), isSelected: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Section Header depending on mode
                HStack {
                    if currentMode == .chats {
                        Text(L10n.tr("Recents", es: "Recientes"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(NewtonTheme.textMuted)
                    } else {
                        HStack(spacing: 6) {
                            Text(L10n.tr("Projects", es: "Proyectos"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(NewtonTheme.textSecondary)
                            
                            Text("•")
                                .foregroundColor(NewtonTheme.textMuted)
                            
                            Text(remoteStatus?.online == true 
                                 ? L10n.tr("Connected to host", es: "Conectado al host") 
                                 : L10n.tr("Disconnected from host", es: "Desconectado del host"))
                                .font(.system(size: 12))
                                .foregroundColor(remoteStatus?.online == true ? Color.green : NewtonTheme.textMuted)
                        }
                    }
                    Spacer()
                    
                    if currentMode == .remoteStudio {
                        Button {
                            Haptics.light()
                            loadRemoteStudioData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(NewtonTheme.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
                
                // Main List Content (Chats List vs Remote Studio Projects Hierarchy)
                if currentMode == .chats {
                    conversationsListView
                } else {
                    remoteStudioProjectsView
                }
                
                Divider()
                    .background(NewtonTheme.border)
                
                // Bottom Bar: Settings Gear on left + Action button on right
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
                    
                    if currentMode == .chats {
                        // "+ New chat" pill button
                        Button(action: createNewChat) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(L10n.tr("New chat", es: "Nuevo chat"))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Color.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                        }
                    } else {
                        // "+ New Task" pill for Remote Studio
                        Button(action: {
                            if let first = remoteWorkspaces.first {
                                openRemoteSession(workspace: first, chat: nil)
                            } else {
                                openRemoteSession(workspace: nil, chat: nil)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(L10n.tr("New Task", es: "Nueva Tarea"))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(NewtonTheme.bg)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(NewtonTheme.sand)
                            .clipShape(Capsule())
                        }
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
        .sheet(isPresented: $showWorkspaces) {
            WorkspaceListView()
        }
        .sheet(isPresented: $showDesktopRemote) {
            DesktopRemoteControlView(
                initialWorkspace: activeRemoteWorkspace,
                initialChat: activeRemoteChat
            )
        }
        .onAppear {
            loadRemoteStatusQuietly()
        }
    }
    
    // MARK: - Conversations List View
    private var conversationsListView: some View {
        List {
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
                        }
                        
                        Text(convo.title)
                            .font(.system(size: 15, weight: convo.isPinned ? .semibold : .regular))
                            .foregroundColor(NewtonTheme.textPrimary)
                            .lineLimit(1)
                        
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
                         Label(convo.isPinned ? L10n.tr("Unpin", es: "Desfijar") : L10n.tr("Pin", es: "Fijar"), systemImage: convo.isPinned ? "pin.slash.fill" : "pin.fill")
                    }
                    .tint(NewtonTheme.sand)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                         Haptics.medium()
                         storage.deleteConversation(id: convo.id)
                    } label: {
                         Label(L10n.tr("Delete", es: "Eliminar"), systemImage: "trash.fill")
                    }
                }
                .contextMenu {
                    Button {
                         Haptics.light()
                         storage.togglePin(id: convo.id)
                    } label: {
                         Label(convo.isPinned ? L10n.tr("Unpin Chat", es: "Desfijar chat") : L10n.tr("Pin Chat", es: "Fijar chat"), systemImage: convo.isPinned ? "pin.slash" : "pin")
                    }
                    
                    Button(role: .destructive) {
                         Haptics.medium()
                         storage.deleteConversation(id: convo.id)
                    } label: {
                         Label(L10n.tr("Delete Chat", es: "Eliminar chat"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await storage.syncWithRemoteServer()
        }
    }
    
    // MARK: - Remote Studio Projects & Chats View
    private var remoteStudioProjectsView: some View {
        List {
            if remoteWorkspaces.isEmpty {
                remoteEmptyView
            } else {
                ForEach(remoteWorkspaces) { ws in
                    workspaceSectionView(ws: ws)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            loadRemoteStudioData()
        }
    }
    
    private var remoteEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 32))
                .foregroundColor(NewtonTheme.textMuted)
            
            Text(remoteStatus?.online == true
                 ? L10n.tr("No workspaces open on host.", es: "No hay proyectos abiertos en el host.")
                 : L10n.tr("Host is offline.", es: "El host está desconectado."))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(NewtonTheme.textSecondary)
            
            Text(L10n.tr("Open Newton on your Mac Desktop to sync your workspaces and project chats.",
                         es: "Abre Newton en tu Mac para sincronizar tus proyectos y chats de código."))
                .font(.system(size: 12))
                .foregroundColor(NewtonTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            Button {
                Haptics.light()
                loadRemoteStudioData()
            } label: {
                Text(L10n.tr("Check Connection", es: "Comprobar Conexión"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NewtonTheme.sand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(NewtonTheme.card)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    @ViewBuilder
    private func workspaceSectionView(ws: CloudChatService.RemoteWorkspaceItem) -> some View {
        let isExpanded = expandedWorkspacePaths.contains(ws.path)
        
        Section {
            // Project Workspace Header Row
            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedWorkspacePaths.remove(ws.path)
                    } else {
                        expandedWorkspacePaths.insert(ws.path)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 15))
                        .foregroundColor(NewtonTheme.sand)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ws.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        if let b = ws.branch, !b.isEmpty {
                            Text(b)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NewtonTheme.textMuted)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(NewtonTheme.textMuted)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            // Workspace Chats (when expanded)
            if isExpanded {
                // "Add chat to project" button
                Button {
                    Haptics.light()
                    openRemoteSession(workspace: ws, chat: nil)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 13))
                            .foregroundColor(NewtonTheme.sand)
                        
                        Text(L10n.tr("New chat in project", es: "Nuevo chat en proyecto"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(NewtonTheme.sand)
                        
                        Spacer()
                    }
                    .padding(.leading, 24)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
                // Existing chats inside this workspace
                if let chats = ws.chats, !chats.isEmpty {
                    ForEach(chats) { chat in
                        workspaceChatRowView(ws: ws, chat: chat)
                    }
                }
            }
        }
    }
    
    private func workspaceChatRowView(ws: CloudChatService.RemoteWorkspaceItem, chat: CloudChatService.RemoteWorkspaceChat) -> some View {
        Button {
            Haptics.selection()
            openRemoteSession(workspace: ws, chat: chat)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 12))
                    .foregroundColor(NewtonTheme.textMuted)
                
                Text(chat.title)
                    .font(.system(size: 14))
                    .foregroundColor(NewtonTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                if let count = chat.messages?.count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(NewtonTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NewtonTheme.card)
                        .clipShape(Capsule())
                }
            }
            .padding(.leading, 24)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    // MARK: - Actions & Data Loading
    
    private func createNewChat() {
        Haptics.light()
        let newConvo = storage.createConversation(title: L10n.tr("New Conversation", es: "Nueva Conversación"))
        selectedConversationId = newConvo.id
        onSelectConversation?(newConvo.id)
    }
    
    private func openRemoteSession(workspace: CloudChatService.RemoteWorkspaceItem?, chat: CloudChatService.RemoteWorkspaceChat?) {
        activeRemoteWorkspace = workspace
        activeRemoteChat = chat
        showDesktopRemote = true
    }
    
    private func loadRemoteStatusQuietly() {
        Task {
            if let st = try? await CloudChatService.shared.fetchDesktopStatus() {
                DispatchQueue.main.async {
                    self.remoteStatus = st
                }
            }
        }
    }
    
    private func loadRemoteStudioData() {
        isFetchingRemote = true
        Task {
            do {
                let st = try await CloudChatService.shared.fetchDesktopStatus()
                let ws = try await CloudChatService.shared.fetchDesktopWorkspaces()
                DispatchQueue.main.async {
                    self.remoteStatus = st
                    self.remoteWorkspaces = ws
                    self.isFetchingRemote = false
                    // Auto-expand all workspaces if first load
                    if self.expandedWorkspacePaths.isEmpty {
                        for item in ws {
                            self.expandedWorkspacePaths.insert(item.path)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isFetchingRemote = false
                }
            }
        }
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
