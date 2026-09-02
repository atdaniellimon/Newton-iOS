//
//  MemoryManager.swift
//  Newton
//
//  Persistent Long-Term Memory Manager for Newton Singularity.
//  Stores key user facts, stack preferences, and projects to provide natural personalized context.
//  100% Model-Driven: populated solely by the AI model during real interactions.
//

import Foundation
import Combine

public struct MemoryItem: Identifiable, Codable, Equatable {
    public var id: String
    public var content: String
    public var category: String
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: String = UUID().uuidString, content: String, category: String = "general", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public final class MemoryManager: ObservableObject {
    public static let shared = MemoryManager()
    
    private let userDefaultsKey = "newton_user_persistent_memories"
    
    @Published public var memories: [MemoryItem] = [] {
        didSet {
            saveMemories()
        }
    }
    
    private init() {
        loadMemories()
    }
    
    public func addMemory(_ content: String, category: String = "general") {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Prevent exact duplicates
        if !memories.contains(where: { $0.content.localizedCaseInsensitiveContains(trimmed) || trimmed.localizedCaseInsensitiveContains($0.content) }) {
            let newItem = MemoryItem(content: trimmed, category: category)
            memories.append(newItem)
        }
    }
    
    public func updateMemory(id: String, newContent: String) {
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = memories.firstIndex(where: { $0.id == id }) {
            memories[idx].content = trimmed
            memories[idx].updatedAt = Date()
        }
    }
    
    public func deleteMemory(id: String) {
        memories.removeAll(where: { $0.id == id })
    }
    
    public func clearAllMemories() {
        memories.removeAll()
    }
    
    public func formattedMemoryPrompt() -> String {
        guard !memories.isEmpty else { return "" }
        var text = ""
        for item in memories {
            text += "• \(item.content)\n"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func saveMemories() {
        if let data = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadMemories() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([MemoryItem].self, from: data) {
            self.memories = decoded
        }
    }
}
