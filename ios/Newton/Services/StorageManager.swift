//
//  StorageManager.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation
import Combine

public final class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public var conversations: [Conversation] = []
    
    private let fileName = "newton_conversations.json"
    
    private init() {
        loadConversations()
    }
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    public func loadConversations() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Create initial welcome conversation
            let welcomeMessage = Message(
                role: .assistant,
                content: "Hello! I am **Newton AI**, your high-precision scientific and coding assistant. How can I assist your research or projects today?"
            )
            let initial = Conversation(
                title: "Welcome to Newton",
                messages: [welcomeMessage]
            )
            self.conversations = [initial]
            saveConversations()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Conversation].self, from: data)
            self.conversations = decoded
        } catch {
            print("Error loading conversations: \(error)")
        }
    }
    
    public func saveConversations() {
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: fileURL, options: [.atomicWrite])
        } catch {
            print("Error saving conversations: \(error)")
        }
    }
    
    public func createConversation(title: String = "New Conversation", provider: AIProvider, modelId: String) -> Conversation {
        let conversation = Conversation(title: title, messages: [], provider: provider, modelId: modelId)
        conversations.insert(conversation, at: 0)
        saveConversations()
        return conversation
    }
    
    public func updateConversation(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
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
}
