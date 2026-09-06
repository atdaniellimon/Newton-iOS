//
//  Message.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public enum MessageRole: String, Codable, Equatable, Hashable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

public struct OrbitExecutionResult: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let orbitName: String
    public let params: String
    public let result: String
    public let isSuccess: Bool
    
    public init(id: String = UUID().uuidString, orbitName: String, params: String, result: String, isSuccess: Bool) {
        self.id = id
        self.orbitName = orbitName
        self.params = params
        self.result = result
        self.isSuccess = isSuccess
    }
    
    enum CodingKeys: String, CodingKey {
        case id, orbitName, params, result, isSuccess
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        orbitName = try container.decodeIfPresent(String.self, forKey: .orbitName) ?? "orbit"
        params = try container.decodeIfPresent(String.self, forKey: .params) ?? ""
        result = try container.decodeIfPresent(String.self, forKey: .result) ?? ""
        isSuccess = try container.decodeIfPresent(Bool.self, forKey: .isSuccess) ?? true
    }
}

public struct Message: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var role: MessageRole
    public var content: String
    public var thinkingContent: String?
    public var imageUrl: String?
    public var orbitResults: [OrbitExecutionResult]
    public var attachments: [FileAttachment]
    public let createdAt: Date
    public var isStreaming: Bool
    
    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        thinkingContent: String? = nil,
        imageUrl: String? = nil,
        orbitResults: [OrbitExecutionResult] = [],
        attachments: [FileAttachment] = [],
        createdAt: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.imageUrl = imageUrl
        self.orbitResults = orbitResults
        self.attachments = attachments
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
    
    enum CodingKeys: String, CodingKey {
        case id, role, content, thinkingContent, imageUrl, orbitResults, attachments, createdAt, isStreaming
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        role = try container.decodeIfPresent(MessageRole.self, forKey: .role) ?? .assistant
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        thinkingContent = try container.decodeIfPresent(String.self, forKey: .thinkingContent)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        orbitResults = try container.decodeIfPresent([OrbitExecutionResult].self, forKey: .orbitResults) ?? []
        attachments = try container.decodeIfPresent([FileAttachment].self, forKey: .attachments) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isStreaming = try container.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false
    }
    
    public static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id &&
               lhs.role == rhs.role &&
               lhs.content == rhs.content &&
               lhs.thinkingContent == rhs.thinkingContent &&
               lhs.imageUrl == rhs.imageUrl &&
               lhs.orbitResults == rhs.orbitResults &&
               lhs.attachments == rhs.attachments &&
               lhs.isStreaming == rhs.isStreaming
    }
}
