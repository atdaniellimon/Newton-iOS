//
//  StorageManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Local JSON & iCloud Ubiquitous Key-Value synchronization with Ephemeral Ghost Mode support.
//

import Foundation

public final class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public var conversations: [Conversation] = []
    
    private let conversationsFileName = "newton_conversations_v1.json"
    private let iCloudKey = "newton_cloud_conversations_v1"
    
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(conversationsFileName)
    }
    
    private init() {
        loadConversations()
        setupCloudObserver()
    }
    
    private func setupCloudObserver() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            self?.loadFromCloud()
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    public func createConversation(title: String = "New Conversation") -> Conversation {
        let newConvo = Conversation(title: title, messages: [])
        conversations.insert(newConvo, at: 0)
        sortConversations()
        saveConversations()
        return newConvo
    }

    public func createGhostConversation(title: String = "Ghost Session") -> Conversation {
        let ghostConvo = Conversation(
            title: title,
            messages: [],
            isPinned: false,
            isGhost: true
        )
        conversations.insert(ghostConvo, at: 0)
        return ghostConvo
    }
    
    public func clearAllConversations() {
        conversations.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
        iCloudSyncService.shared.clearCloudData()
    }
    
    public func purgeGhostConversations() {
        conversations.removeAll(where: { $0.isGhost })
    }
    
    public func updateConversation(_ convo: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == convo.id }) {
            var updated = convo
            updated.updatedAt = Date()
            conversations[index] = updated
            sortConversations()
            if !convo.isGhost {
                saveConversations()
            }
        }
    }
    
    public func togglePin(id: String) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].isPinned.toggle()
            sortConversations()
            if !conversations[index].isGhost {
                saveConversations()
            }
        }
    }
    
    public func deleteConversation(at offsets: IndexSet) {
        conversations.remove(atOffsets: offsets)
        saveConversations()
    }
    
    public func deleteConversation(id: String) {
        conversations.removeAll(where: { $0.id == id })
        saveConversations()
    }
    
    public func sortConversations() {
        conversations.sort { (a, b) -> Bool in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.updatedAt > b.updatedAt
        }
    }
    
    public func saveConversations() {
        do {
            let persistentConvos = conversations.filter { !$0.isGhost }
            let data = try JSONEncoder().encode(persistentConvos)
            // 1. Save to Local File
            try data.write(to: fileURL, options: [.atomicWrite])
            
            // 2. Sync to iCloud Ubiquitous Key-Value Storage
            NSUbiquitousKeyValueStore.default.set(data, forKey: iCloudKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        } catch {
            print("Error saving conversations: \(error)")
        }
    }
    
    private func loadFromCloud() {
        if let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: iCloudKey),
           let cloudConvos = try? JSONDecoder().decode([Conversation].self, from: cloudData),
           !cloudConvos.isEmpty {
            let ghosts = self.conversations.filter { $0.isGhost }
            self.conversations = ghosts + cloudConvos
            sortConversations()
        }
    }
    
    private func loadConversations() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let loaded = try JSONDecoder().decode([Conversation].self, from: data)
                if !loaded.isEmpty {
                    self.conversations = loaded
                    sortConversations()
                    return
                }
            } catch {
                print("Error loading local conversations: \(error)")
            }
        }
        
        loadFromCloud()
    }
    
    // MARK: - Remote Server Synchronization (api.newton.daniellimon.uk)
    
    @MainActor
    public func syncWithRemoteServer() async {
        guard AuthManager.shared.isLoggedIn else { return }
        do {
            // 1. Fetch Standard Cloud Chats
            let remoteChats = try await CloudChatService.shared.fetchChats(limit: 100)
            
            // 2. Fetch Remote Desktop Workspaces Code Chats
            var remoteCodeConversations: [Conversation] = []
            if let workspaces = try? await CloudChatService.shared.fetchDesktopWorkspaces() {
                for ws in workspaces {
                    if let chats = ws.chats {
                        for chat in chats {
                            // Convert raw message dictionaries to Message models
                            var chatMessages: [Message] = []
                            if let rawMsgs = chat.messages {
                                for (idx, raw) in rawMsgs.enumerated() {
                                    let roleStr = raw["role"] ?? "user"
                                    let contentStr = raw["content"] ?? ""
                                    let role: MessageRole = (roleStr == "user") ? .user : .assistant
                                    chatMessages.append(Message(
                                        id: "\(chat.id)_msg_\(idx)",
                                        role: role,
                                        content: contentStr,
                                        createdAt: Date(timeIntervalSince1970: chat.created_at ?? Date().timeIntervalSince1970)
                                    ))
                                }
                            }
                            
                            let date = chat.created_at.map { Date(timeIntervalSince1970: $0) } ?? Date()
                            let codeConvo = Conversation(
                                id: chat.id,
                                title: chat.title.isEmpty ? "Code Task" : chat.title,
                                messages: chatMessages,
                                isPinned: false,
                                isGhost: false,
                                modelId: "Singularity-Matrix",
                                isRemoteCodeChat: true,
                                workspacePath: ws.path,
                                workspaceName: ws.name,
                                createdAt: date,
                                updatedAt: date
                            )
                            remoteCodeConversations.append(codeConvo)
                        }
                    }
                }
            }
            
            let ghosts = self.conversations.filter { $0.isGhost }
            var merged: [Conversation] = []
            
            // Merge Standard Cloud Chats
            for rChat in remoteChats {
                if let existing = self.conversations.first(where: { $0.id == rChat.id }) {
                    var updated = rChat
                    updated.isPinned = rChat.isPinned
                    updated.title = rChat.title
                    updated.modelId = rChat.modelId
                    if !existing.messages.isEmpty {
                        updated.messages = existing.messages
                    }
                    merged.append(updated)
                } else {
                    merged.append(rChat)
                }
            }
            
            // Merge Remote Workspace Code Chats
            for cChat in remoteCodeConversations {
                if let existing = self.conversations.first(where: { $0.id == cChat.id }) {
                    var updated = cChat
                    updated.isPinned = existing.isPinned
                    if !existing.messages.isEmpty && cChat.messages.isEmpty {
                        updated.messages = existing.messages
                    }
                    merged.append(updated)
                } else {
                    merged.append(cChat)
                }
            }
            
            self.conversations = ghosts + merged
            self.sortConversations()
            self.saveConversations()
        } catch {
            print("Failed to sync chats with remote server: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    public func handleRemoteSyncEvent(_ event: CloudSyncEvent) {
        guard let chatId = event.chatId else { return }
        switch event.event {
        case .chatCreated:
            if !conversations.contains(where: { $0.id == chatId }) {
                let newConvo = Conversation(
                    id: chatId,
                    title: event.title ?? "New Conversation",
                    messages: [],
                    isPinned: event.isPinned ?? false,
                    isGhost: false,
                    modelId: event.model ?? SettingsManager.shared.currentModelId,
                    createdAt: event.updatedAt ?? Date(),
                    updatedAt: event.updatedAt ?? Date()
                )
                conversations.insert(newConvo, at: 0)
                sortConversations()
                saveConversations()
            }
        case .chatUpdated:
            if let index = conversations.firstIndex(where: { $0.id == chatId }) {
                var updated = conversations[index]
                if let t = event.title { updated.title = t }
                if let p = event.isPinned { updated.isPinned = p }
                if let m = event.model { updated.modelId = m }
                if let u = event.updatedAt { updated.updatedAt = u }
                conversations[index] = updated
                sortConversations()
                saveConversations()
            }
        case .chatDeleted:
            deleteConversation(id: chatId)
        case .desktopStatus, .unknown:
            break
        }
    }
}
