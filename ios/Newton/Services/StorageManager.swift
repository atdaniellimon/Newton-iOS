//
//  StorageManager.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public final class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public var conversations: [Conversation] = []
    
    private let conversationsFileName = "newton_conversations_v1.json"
    
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(conversationsFileName)
    }
    
    private init() {
        loadConversations()
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
    
    private func saveConversations() {
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: fileURL, options: [.atomicWrite])
        } catch {
            print("Error saving conversations: \(error)")
        }
    }
    
    private func loadConversations() {
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
