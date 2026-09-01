//
//  Conversation.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public struct Conversation: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var provider: AIProvider
    public var modelId: String
    public var messages: [Message]
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String = "New Conversation",
        provider: AIProvider = .openrouter,
        modelId: String = "anthropic/claude-3.5-sonnet",
        messages: [Message] = [],
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.modelId = modelId
        self.messages = messages
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.provider == rhs.provider &&
               lhs.modelId == rhs.modelId &&
               lhs.messages == rhs.messages &&
               lhs.isPinned == rhs.isPinned &&
               lhs.updatedAt == rhs.updatedAt
    }
}
