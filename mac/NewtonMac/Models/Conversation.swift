//
//  Conversation.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import Foundation

public struct Conversation: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var provider: AIProvider
    public var modelId: String
    public var messages: [Message]
    public var isPinned: Bool
    public var isGhost: Bool
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String = "New Conversation",
        provider: AIProvider = .openrouter,
        modelId: String = "anthropic/claude-3.5-sonnet",
        messages: [Message] = [],
        isPinned: Bool = false,
        isGhost: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.modelId = modelId
        self.messages = messages
        self.isPinned = isPinned
        self.isGhost = isGhost
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, provider, modelId, messages, isPinned, isGhost, createdAt, updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "New Conversation"
        provider = try container.decodeIfPresent(AIProvider.self, forKey: .provider) ?? .openrouter
        modelId = try container.decodeIfPresent(String.self, forKey: .modelId) ?? "anthropic/claude-3.5-sonnet"
        messages = try container.decodeIfPresent([Message].self, forKey: .messages) ?? []
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isGhost = try container.decodeIfPresent(Bool.self, forKey: .isGhost) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
    
    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.provider == rhs.provider &&
               lhs.modelId == rhs.modelId &&
               lhs.messages == rhs.messages &&
               lhs.isPinned == rhs.isPinned &&
               lhs.isGhost == rhs.isGhost &&
               lhs.updatedAt == rhs.updatedAt
    }
}
