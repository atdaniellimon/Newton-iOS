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
    
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    @State private var showArtGallery: Bool = false
    
    public init(selectedConversationId: Binding<String?>, onSelectConversation: ((String) -> Void)? = nil) {
        self._selectedConversationId = selectedConversationId
        self.onSelectConversation = onSelectConversation
    }
    
    private var allConversations: [Conversation] {
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
                
                // Studio Section Navigation Items (Ghost, Remote Studio, Art gallery)
                VStack(spacing: 6) {
                    Button {
                        Haptics.medium()
                        let ghost = storage.createGhostConversation()
                        selectedConversationId = ghost.id
                        onSelectConversation?(ghost.id)
                    } label: {
                        SidebarItemRow(icon: "ghost", title: "Sesión Fantasma", subtitle: "Efímera, sin rastro en la nube", tint: Color(red: 0.75, green: 0.55, blue: 0.95))
                    }
                    
                    Button {
                        Haptics.light()
                        let firstWs = cloudService.desktopWorkspaces.first
                        let taskId = "task_\(Int(Date().timeIntervalSince1970))"
                        let remoteConvo = Conversation(
                            id: taskId,
                            title: "Remote Code Task",
                            messages: [],
                            isPinned: false,
                            isGhost: false,
                            modelId: "Singularity-Matrix",
                            isRemoteCodeChat: true,
                            workspacePath: firstWs?.path,
                            workspaceName: firstWs?.name,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        storage.conversations.insert(remoteConvo, at: 0)
                        storage.sortConversations()
                        storage.saveConversations()
                        selectedConversationId = remoteConvo.id
                        onSelectConversation?(remoteConvo.id)
                    } label: {
                        SidebarItemRow(icon: "laptopcomputer", title: "Remote Studio (Mac)", subtitle: "Consola, workspaces y herramientas", tint: NewtonTheme.aqua)
                    }
                    
                    Button {
                        Haptics.light()
                        showArtGallery = true
                    } label: {
                        SidebarItemRow(icon: "cube.transparent", title: "Galería de arte", subtitle: "Creaciones visuales generadas", tint: NewtonTheme.sand)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Conversations List with Pinning and Deletion
                List {
                    // Pinned Section (if any)
                    let pinned = allConversations.filter { $0.isPinned }
                    let recents = allConversations.filter { !$0.isPinned }
                    
                    if !pinned.isEmpty {
                        Section(header: Text("FIJADOS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(NewtonTheme.textMuted)
                            .padding(.leading, -10)) {
                            ForEach(pinned) { convo in
                                conversationRow(convo: convo)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
                    }
                    
                    Section(header: Text(pinned.isEmpty ? "CONVERSACIONES" : "RECIENTES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NewtonTheme.textMuted)
                        .padding(.leading, -10)) {
                        if recents.isEmpty && pinned.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundColor(NewtonTheme.textMuted.opacity(0.6))
                                    .padding(.top, 40)
                                
                                Text("No hay conversaciones aún")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(NewtonTheme.textSecondary)
                                
                                Text("Inicia un nuevo chat con el botón '+'.")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(recents) { convo in
                                conversationRow(convo: convo)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
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
        .onAppear {
            Task {
                await storage.syncWithRemoteServer()
                await cloudService.refreshHostStatus()
            }
        }
    }
    
    @ViewBuilder
    private func conversationRow(convo: Conversation) -> some View {
        let isSelected = selectedConversationId == convo.id
        let lastMessageText: String = {
            guard let last = convo.messages.last else { return "Sin mensajes" }
            if !last.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return last.content.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
            } else if let thinking = last.thinkingContent, !thinking.isEmpty {
                return "Pensamiento formulado..."
            } else if let orbit = last.orbitResults.first {
                return "Ejecución Orbit: \(orbit.orbitName)"
            } else {
                return "Adjunto"
            }
        }()
        
        Button(action: {
            Haptics.selection()
            selectedConversationId = convo.id
            onSelectConversation?(convo.id)
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    // Line 1: Badges & Title
                    HStack(spacing: 6) {
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
                                .foregroundColor(NewtonTheme.aqua)
                        }
                        
                        Text(convo.title)
                            .font(.system(size: 15, weight: convo.isPinned ? .semibold : .regular))
                            .foregroundColor(isSelected ? NewtonTheme.textPrimary : NewtonTheme.textPrimary.opacity(0.9))
                            .lineLimit(1)
                        
                        if convo.isRemoteCodeChat, let wsName = convo.workspaceName, !wsName.isEmpty {
                            Text(wsName)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(NewtonTheme.aqua)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(NewtonTheme.aqua.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    
                    // Line 2: Last message snippet
                    Text(lastMessageText)
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textSecondary.opacity(0.85))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Relative timestamp
                Text(relativeDateString(convo.updatedAt))
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? NewtonTheme.card.opacity(0.8) : (convo.isPinned ? NewtonTheme.card.opacity(0.3) : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contextMenu {
            Button {
                Haptics.medium()
                storage.togglePin(id: convo.id)
            } label: {
                Label(convo.isPinned ? "Desfijar" : "Fijar arriba", systemImage: convo.isPinned ? "pin.slash" : "pin")
            }
            
            Button(role: .destructive) {
                Haptics.medium()
                storage.deleteConversation(id: convo.id)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Haptics.medium()
                storage.deleteConversation(id: convo.id)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            .tint(NewtonTheme.coralRed)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                Haptics.medium()
                storage.togglePin(id: convo.id)
            } label: {
                Label(convo.isPinned ? "Desfijar" : "Fijar", systemImage: convo.isPinned ? "pin.slash" : "pin")
            }
            .tint(NewtonTheme.sand)
        }
    }
    
    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func createNewChat() {
        Haptics.light()
        let newConvo = storage.createConversation()
        selectedConversationId = newConvo.id
        onSelectConversation?(newConvo.id)
    }
}

public struct SidebarItemRow: View {
    public let icon: String
    public let title: String
    public var subtitle: String? = nil
    public var tint: Color = NewtonTheme.sand
    public var isSelected: Bool = false
    
    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(tint)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(NewtonTheme.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.textMuted)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NewtonTheme.card.opacity(isSelected ? 0.8 : 0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NewtonTheme.border.opacity(0.3), lineWidth: 0.5)
        )
    }
}
