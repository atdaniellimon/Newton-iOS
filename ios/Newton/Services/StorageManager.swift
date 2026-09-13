//
//  StorageManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Local JSON & iCloud Ubiquitous Key-Value synchronization with Ephemeral Ghost Mode support.
//  Fully integrated with Newton Labs Gateway v2.2.0 Cloud Chat API (/nwtn/chats & /nwtn/sync/events).
//

import Foundation
import Combine

public final class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public var conversations: [Conversation] = []
    
    private let conversationsFileName = "newton_conversations_v1.json"
    private let iCloudKey = "newton_cloud_conversations_v1"
    
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(conversationsFileName)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadConversations()
        setupCloudObserver()
        setupAuthObserver()
        setupGlobalSyncListener()
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
    
    private func setupAuthObserver() {
        // When user logs in, pull remote cloud chats
        AuthManager.shared.$isLoggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loggedIn in
                guard let self = self else { return }
                if loggedIn {
                    Task { @MainActor [weak self] in
                        await self?.syncWithRemoteServer()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupGlobalSyncListener() {
        CloudChatService.shared.startGlobalSyncListener { [weak self] event in
            guard let self = self else { return }
            self.handleRemoteSyncEvent(event)
        }
    }
    
    // MARK: - Server Synchronization
    
    @MainActor
    public func syncWithRemoteServer() async {
        guard AuthManager.shared.isLoggedIn else { return }
        do {
            let remoteChats = try await CloudChatService.shared.fetchChats()
            // Keep local ghosts
            let ghosts = self.conversations.filter { $0.isGhost }
            
            // Merge remote chats with local messages if available
            var merged: [Conversation] = []
            for rChat in remoteChats {
                if let existing = self.conversations.first(where: { $0.id == rChat.id }) {
                    var updated = rChat
                    // Preserve already loaded local messages
                    if !existing.messages.isEmpty {
                        updated.messages = existing.messages
                    }
                    merged.append(updated)
                } else {
                    merged.append(rChat)
                }
            }
            
            self.conversations = ghosts + merged
            sortConversations()
            saveConversations()
        } catch {
            print("Remote cloud sync failed: \(error.localizedDescription)")
        }
    }
    
    private func handleRemoteSyncEvent(_ event: CloudSyncEvent) {
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
                    createdAt: Date(),
                    updatedAt: event.updatedAt ?? Date()
                )
                conversations.insert(newConvo, at: 0)
                sortConversations()
                saveConversations()
            }
        case .chatUpdated:
            if let idx = conversations.firstIndex(where: { $0.id == chatId }) {
                if let title = event.title {
                    conversations[idx].title = title
                }
                if let isPinned = event.isPinned {
                    conversations[idx].isPinned = isPinned
                }
                if let model = event.model {
                    conversations[idx].modelId = model
                }
                if let updated = event.updatedAt {
                    conversations[idx].updatedAt = updated
                }
                sortConversations()
                saveConversations()
            }
        case .chatDeleted:
            conversations.removeAll(where: { $0.id == chatId })
            saveConversations()
        case .unknown:
            break
        }
    }
    
    // MARK: - Conversation Lifecycle
    
    public func createConversation(title: String = "New Conversation") -> Conversation {
        let newConvo = Conversation(title: title, messages: [])
        conversations.insert(newConvo, at: 0)
        sortConversations()
        saveConversations()
        
        // Asynchronously persist to remote cloud chat API
        if AuthManager.shared.isLoggedIn {
            Task {
                do {
                    _ = try await CloudChatService.shared.createChat(
                        title: title,
                        model: newConvo.modelId
                    )
                } catch {
                    print("Failed to sync new chat to cloud API: \(error.localizedDescription)")
                }
            }
        }
        
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
                if AuthManager.shared.isLoggedIn {
                    Task {
                        try? await CloudChatService.shared.updateChat(
                            id: convo.id,
                            title: convo.title,
                            isPinned: convo.isPinned,
                            model: convo.modelId
                        )
                    }
                }
            }
        }
    }
    
    public func togglePin(id: String) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].isPinned.toggle()
            let isPinned = conversations[index].isPinned
            let isGhost = conversations[index].isGhost
            sortConversations()
            if !isGhost {
                saveConversations()
                if AuthManager.shared.isLoggedIn {
                    Task {
                        try? await CloudChatService.shared.updateChat(
                            id: id,
                            isPinned: isPinned
                        )
                    }
                }
            }
        }
    }
    
    public func deleteConversation(at offsets: IndexSet) {
        let idsToDelete = offsets.map { conversations[$0].id }
        conversations.remove(atOffsets: offsets)
        saveConversations()
        
        if AuthManager.shared.isLoggedIn {
            for id in idsToDelete {
                Task {
                    try? await CloudChatService.shared.deleteChat(id: id)
                }
            }
        }
    }
    
    public func deleteConversation(id: String) {
        let wasGhost = conversations.first(where: { $0.id == id })?.isGhost ?? false
        conversations.removeAll(where: { $0.id == id })
        saveConversations()
        
        if !wasGhost && AuthManager.shared.isLoggedIn {
            Task {
                try? await CloudChatService.shared.deleteChat(id: id)
            }
        }
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
}
