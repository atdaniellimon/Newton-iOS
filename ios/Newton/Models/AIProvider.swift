//
//  AIProvider.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case newton = "nwtn"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        return "Newton"
    }
    
    public var defaultBaseUrl: String {
        return SettingsManager.nwtnBaseURL
    }
    
    public var isCustomOrLocal: Bool {
        return false
    }
    
    public var isAnthropicProtocol: Bool {
        return false
    }
    
    public var defaultModelId: String {
        return "Singularity"
    }
    
    public var iconName: String {
        return "atom"
    }
}
