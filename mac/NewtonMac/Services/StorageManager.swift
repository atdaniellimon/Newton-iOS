//
//  StorageManager.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Local JSON & iCloud Ubiquitous Key-Value synchronization with Ephemeral Ghost Mode support.
//

import Foundation

public final class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public var conversations: [Conversation] = []
    
    private let conversationsFileName = "newton_conversations_v1.json"
    private let iCloudKey = "newton_cloud_conversations_v1"
    
    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let newtonDir = appSupport.appendingPathComponent("NewtonMac", isDirectory: true)
        if !FileManager.default.fileExists(atPath: newtonDir.path) {
            try? FileManager.default.createDirectory(at: newtonDir, withIntermediateDirectories: true)
        }
        return newtonDir.appendingPathComponent(conversationsFileName)
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
    
    public func createConversation(provider: AIProvider, modelId: String, title: String = "New Conversation") -> Conversation {
        let newConvo = Conversation(
            title: title,
            provider: provider,
            modelId: modelId,
            messages: []
        )
        conversations.insert(newConvo, at: 0)
        sortConversations()
        saveConversations()
        return newConvo
    }
    
    public func createConversation(title: String = "New Conversation") -> Conversation {
        let provider = SettingsManager.shared.currentProvider
        let modelId = SettingsManager.shared.currentModelId
        return createConversation(provider: provider, modelId: modelId, title: title)
    }
    
    public func createGhostConversation(title: String = "Ghost Session") -> Conversation {
        let provider = SettingsManager.shared.currentProvider
        let modelId = SettingsManager.shared.currentModelId
        let ghostConvo = Conversation(
            title: title,
            provider: provider,
            modelId: modelId,
            messages: [],
            isPinned: false,
            isGhost: true
        )
        conversations.insert(ghostConvo, at: 0)
        return ghostConvo
    }
    
    public func clearAllConversations() {
        conversations.removeAll()
        saveConversations()
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
}
