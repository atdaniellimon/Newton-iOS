//
//  Message.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public enum MessageRole: String, Codable, Equatable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

public struct OrbitExecutionResult: Identifiable, Codable, Equatable {
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
}

public struct Message: Identifiable, Codable, Equatable {
    public let id: String
    public var role: MessageRole
    public var content: String
    public var thinkingContent: String?
    public var imageUrl: String?
    public var orbitResults: [OrbitExecutionResult]
    public let createdAt: Date
    public var isStreaming: Bool
    
    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        thinkingContent: String? = nil,
        imageUrl: String? = nil,
        orbitResults: [OrbitExecutionResult] = [],
        createdAt: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.imageUrl = imageUrl
        self.orbitResults = orbitResults
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
    
    public static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id &&
               lhs.role == rhs.role &&
               lhs.content == rhs.content &&
               lhs.thinkingContent == rhs.thinkingContent &&
               lhs.imageUrl == rhs.imageUrl &&
               lhs.isStreaming == rhs.isStreaming &&
               lhs.orbitResults == rhs.orbitResults
    }
}
