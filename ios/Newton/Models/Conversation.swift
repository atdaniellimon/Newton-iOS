//
//  Conversation.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public struct Conversation: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var messages: [Message]
    public var provider: AIProvider
    public var modelId: String
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String = "New Conversation",
        messages: [Message] = [],
        provider: AIProvider = .openrouter,
        modelId: String = "anthropic/claude-3.5-sonnet",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.provider = provider
        self.modelId = modelId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
