//
//  StorageManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Local JSON & iCloud Ubiquitous Key-Value synchronization.
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
    
    public func clearAllConversations() {
        conversations.removeAll()
        saveConversations()
    }
    
    public func updateConversation(_ convo: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == convo.id }) {
            var updated = convo
            updated.updatedAt = Date()
            conversations[index] = updated
            sortConversations()
            saveConversations()
        }
    }
    
    public func togglePin(id: String) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].isPinned.toggle()
            sortConversations()
            saveConversations()
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
            let data = try JSONEncoder().encode(conversations)
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
            self.conversations = cloudConvos
            sortConversations()
        }
    }
    
    private func loadConversations() {
        // 1. Try loading from iCloud first
        if let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: iCloudKey),
           let cloudConvos = try? JSONDecoder().decode([Conversation].self, from: cloudData),
           !cloudConvos.isEmpty {
            self.conversations = cloudConvos
            sortConversations()
            return
        }
        
        // 2. Try loading from Local File
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let welcome = Conversation(
                title: "Welcome to Newton",
                provider: .openrouter,
                modelId: "anthropic/claude-3.5-sonnet",
                messages: [
                    Message(
                        role: .assistant,
                        content: "Welcome to Newton. An elegant, private AI interface designed for deep reasoning, creative writing, and high-performance coding."
                    )
                ]
            )
            self.conversations = [welcome]
            saveConversations()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([Conversation].self, from: data)
            self.conversations = loaded
            sortConversations()
        } catch {
            print("Error loading conversations: \(error)")
        }
    }
}
