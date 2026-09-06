//
//  Workspace.swift
//  Newton
//
//  Project & Workspace context model for isolated project folders and context.
//

import Foundation

public struct Workspace: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var customSystemPrompt: String
    public var attachedFiles: [FileAttachment]
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "#F5A623",
        customSystemPrompt: String = "",
        attachedFiles: [FileAttachment] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.customSystemPrompt = customSystemPrompt
        self.attachedFiles = attachedFiles
        self.createdAt = createdAt
    }
}
