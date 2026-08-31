//
//  AIProvider.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openrouter = "openrouter"
    case openai = "openai"
    case anthropic = "anthropic"
    case openaiCompatible = "openai_compatible"
    case anthropicCompatible = "anthropic_compatible"
    case gemini = "gemini"
    case groq = "groq"
    case deepseek = "deepseek"
    case ollama = "ollama"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .openrouter:
            return "OpenRouter"
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .openaiCompatible:
            return "OpenAI Compatible (Custom / Local)"
        case .anthropicCompatible:
            return "Anthropic Compatible (Custom / Proxy)"
        case .gemini:
            return "Google Gemini"
        case .groq:
            return "Groq"
        case .deepseek:
            return "DeepSeek"
        case .ollama:
            return "Ollama (Local API)"
        }
    }
    
    public var defaultBaseUrl: String {
        switch self {
        case .openrouter:
            return "https://openrouter.ai/api/v1"
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        case .openaiCompatible:
            return "http://localhost:1234/v1"
        case .anthropicCompatible:
            return "https://api.anthropic.com/v1"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .groq:
            return "https://api.groq.com/openai/v1"
        case .deepseek:
            return "https://api.deepseek.com/v1"
        case .ollama:
            return "http://localhost:11434/v1"
        }
    }
    
    public var isCustomOrLocal: Bool {
        switch self {
        case .ollama, .openaiCompatible, .anthropicCompatible:
            return true
        default:
            return false
        }
    }
    
    public var isAnthropicProtocol: Bool {
        return self == .anthropic || self == .anthropicCompatible
    }
    
    public var defaultModelId: String {
        switch self {
        case .openrouter:
            return "anthropic/claude-3.5-sonnet"
        case .openai:
            return "gpt-4o-mini"
        case .anthropic:
            return "claude-3-7-sonnet-20250219"
        case .openaiCompatible:
            return "default"
        case .anthropicCompatible:
            return "claude-3-7-sonnet-20250219"
        case .gemini:
            return "gemini-1.5-flash"
        case .groq:
            return "llama-3.3-70b-versatile"
        case .deepseek:
            return "deepseek-chat"
        case .ollama:
            return "llama3"
        }
    }
    
    public var iconName: String {
        switch self {
        case .openrouter:
            return "globe"
        case .openai:
            return "cpu"
        case .anthropic:
            return "sparkles"
        case .openaiCompatible:
            return "network"
        case .anthropicCompatible:
            return "arrow.triangle.swap"
        case .gemini:
            return "sparkle"
        case .groq:
            return "bolt.fill"
        case .deepseek:
            return "brain.head.profile"
        case .ollama:
            return "server.rack"
        }
    }
}
