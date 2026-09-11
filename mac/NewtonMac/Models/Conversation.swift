//
//  Conversation.swift
//  Newton
//
//  Simplified for Newton Singularity — provider/modelId fields removed.
//  Old JSON with provider/modelId is decoded gracefully (fields ignored).
//

import Foundation

public struct Conversation: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var messages: [Message]
    public var isPinned: Bool
    public var isGhost: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public var workspacePath: String? = nil

    // Forward-compat shims so callers that reference these don't hard-fail
    public var provider: String { "nwtn" }
    public var modelId: String  { "Singularity" }

    public init(
        id: String = UUID().uuidString,
        title: String = "New Conversation",
        messages: [Message] = [],
        isPinned: Bool = false,
        isGhost: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id        = id
        self.title     = title
        self.messages  = messages
        self.isPinned  = isPinned
        self.isGhost   = isGhost
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, messages, isPinned, isGhost, createdAt, updatedAt
        // provider, modelId intentionally omitted — decode gracefully below
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decodeIfPresent(String.self,    forKey: .id)        ?? UUID().uuidString
        title     = try c.decodeIfPresent(String.self,    forKey: .title)     ?? "New Conversation"
        messages  = try c.decodeIfPresent([Message].self, forKey: .messages)  ?? []
        isPinned  = try c.decodeIfPresent(Bool.self,      forKey: .isPinned)  ?? false
        isGhost   = try c.decodeIfPresent(Bool.self,      forKey: .isGhost)   ?? false
        createdAt = try c.decodeIfPresent(Date.self,      forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self,      forKey: .updatedAt) ?? Date()
    }

    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id        == rhs.id        &&
        lhs.title     == rhs.title     &&
        lhs.messages  == rhs.messages  &&
        lhs.isPinned  == rhs.isPinned  &&
        lhs.isGhost   == rhs.isGhost   &&
        lhs.updatedAt == rhs.updatedAt
    }
}.