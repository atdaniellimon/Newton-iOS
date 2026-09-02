//
//  MemoryManager.swift
//  Newton
//
//  Persistent Long-Term Memory Manager for Newton Singularity.
//  Stores key user facts, stack preferences, and projects to provide natural personalized context.
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
        if memories.isEmpty {
            seedDefaultMemories()
        }
    }
    
    public func addMemory(_ content: String, category: String = "general") {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Prevent near-duplicate entries
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
    
    private func seedDefaultMemories() {
        let seedFacts = [
            "Name is Daniel",
            "Self-taught developer and entrepreneur",
            "Based in Xalapa, Veracruz, Mexico",
            "Works independently across multiple technical projects simultaneously",
            "Has a private company called Daniel Limón",
            "Has a fictional company called Moke LLC associated with some projects",
            "Technical stack spans C, RISC-V/x86 assembly, Swift, Python, JavaScript, and HTML/CSS",
            "Broad technical interests: systems programming, language design, AI, and product design",
            "Approximately 22 years old, self-taught systems programmer, university student",
            "Operates a multi-brand holding company called @Daniel Limón, with sub-brands spanning luxury interior design (ZTRN), automotive (Darwin Automobili, Moke Automotive), and tech projects",
            "Has backgrounds in graphic design, engineering, architecture, and mechanics",
            "Grounds decisions in philosophical or emotional truth before moving to aesthetics or implementation"
        ]
        
        self.memories = seedFacts.map { MemoryItem(content: $0, category: "profile") }
    }
}
