//
//  AIModel.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public struct AIModel: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let provider: AIProvider
    public let description: String
    public let iconName: String
    public let capabilities: [String]
    public let ownedBy: String
    
    public init(
        id: String = "Singularity",
        name: String = "Newton Singularity",
        provider: AIProvider = .newton,
        description: String = "General-purpose assistant: chat, vision, image generation.",
        iconName: String = "atom",
        capabilities: [String] = ["chat", "vision", "images"],
        ownedBy: String = "Newton Labs"
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.description = description
        self.iconName = iconName
        self.capabilities = capabilities
        self.ownedBy = ownedBy
    }

    public static let singularity = AIModel(
        id: "Singularity",
        name: "Newton Singularity",
        provider: .newton,
        description: "General-purpose assistant: chat, vision, image generation.",
        iconName: "atom",
        capabilities: ["chat", "vision", "images"],
        ownedBy: "Newton Labs"
    )

    public static let singularityMatrix = AIModel(
        id: "Singularity-Matrix",
        name: "Singularity Matrix",
        provider: .newton,
        description: "Programming specialist: code-first, debugging, architecture, refactors.",
        iconName: "chevron.left.forwardslash.chevron.right",
        capabilities: ["chat", "code", "vision"],
        ownedBy: "Newton Labs"
    )
}

public struct DefaultModelCatalog {
    public static func models(for provider: AIProvider = .newton) -> [AIModel] {
        return [AIModel.singularity, AIModel.singularityMatrix]
    }
}
