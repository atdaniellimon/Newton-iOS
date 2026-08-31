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
    
    public init(id: String, name: String, provider: AIProvider, description: String = "", iconName: String = "sparkles") {
        self.id = id
        self.name = name
        self.provider = provider
        self.description = description
        self.iconName = iconName
    }
}

public struct DefaultModelCatalog {
    public static func models(for provider: AIProvider) -> [AIModel] {
        switch provider {
        case .openrouter:
            return [
                AIModel(id: "anthropic/claude-3.5-sonnet", name: "Claude 3.5 Sonnet", provider: .openrouter, description: "Top tier reasoning & code"),
                AIModel(id: "deepseek/deepseek-r1", name: "DeepSeek R1", provider: .openrouter, description: "SOTA reasoning model"),
                AIModel(id: "openai/gpt-4o", name: "GPT-4o", provider: .openrouter, description: "Flagship multimodal"),
                AIModel(id: "openai/gpt-4o-mini", name: "GPT-4o Mini", provider: .openrouter, description: "Fast & lightweight"),
                AIModel(id: "meta-llama/llama-3.3-70b-instruct", name: "Llama 3.3 70B", provider: .openrouter, description: "Open source leader"),
                AIModel(id: "google/gemini-2.0-flash-exp:free", name: "Gemini 2.0 Flash (Free)", provider: .openrouter, description: "Fast experimental model")
            ]
        case .openai:
            return [
                AIModel(id: "gpt-4o", name: "GPT-4o", provider: .openai, description: "Flagship intelligence"),
                AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: .openai, description: "Fast & affordable"),
                AIModel(id: "o3-mini", name: "o3-mini", provider: .openai, description: "Reasoning for STEM & code"),
                AIModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", provider: .openai, description: "Previous generation flagship")
            ]
        case .anthropic:
            return [
                AIModel(id: "claude-3-7-sonnet-20250219", name: "Claude 3.7 Sonnet", provider: .anthropic, description: "Hybrid reasoning & speed"),
                AIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: .anthropic, description: "High-intelligence code & analysis"),
                AIModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: .anthropic, description: "Fastest compact Claude model"),
                AIModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: .anthropic, description: "Deep analysis & writing")
            ]
        case .openaiCompatible:
            return [
                AIModel(id: "default", name: "Default Server Model", provider: .openaiCompatible, description: "Active loaded model"),
                AIModel(id: "gpt-4o", name: "GPT-4o", provider: .openaiCompatible, description: "OpenAI-compatible GPT-4o"),
                AIModel(id: "llama-3.3-70b-instruct", name: "Llama 3.3 70B", provider: .openaiCompatible, description: "Hosted or local Llama"),
                AIModel(id: "deepseek-r1", name: "DeepSeek R1", provider: .openaiCompatible, description: "Local reasoning model"),
                AIModel(id: "qwen2.5-coder-32b-instruct", name: "Qwen 2.5 Coder 32B", provider: .openaiCompatible, description: "Code specialist")
            ]
        case .anthropicCompatible:
            return [
                AIModel(id: "claude-3-7-sonnet-20250219", name: "Claude 3.7 Sonnet", provider: .anthropicCompatible, description: "Proxy / Gateway Anthropic 3.7"),
                AIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: .anthropicCompatible, description: "Proxy / Gateway Anthropic 3.5"),
                AIModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: .anthropicCompatible, description: "Proxy / Gateway Anthropic Haiku")
            ]
        case .gemini:
            return [
                AIModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", provider: .gemini, description: "Fast performance"),
                AIModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", provider: .gemini, description: "Complex reasoning"),
                AIModel(id: "gemini-2.0-flash-exp", name: "Gemini 2.0 Flash Exp", provider: .gemini, description: "Next-gen experimental")
            ]
        case .groq:
            return [
                AIModel(id: "llama-3.3-70b-versatile", name: "Llama 3.3 70B", provider: .groq, description: "Ultra-fast inference"),
                AIModel(id: "deepseek-r1-distill-llama-70b", name: "DeepSeek R1 Distill 70B", provider: .groq, description: "Fast reasoning on Groq"),
                AIModel(id: "mixtral-8x7b-32768", name: "Mixtral 8x7B", provider: .groq, description: "Mixture of experts")
            ]
        case .deepseek:
            return [
                AIModel(id: "deepseek-chat", name: "DeepSeek-V3", provider: .deepseek, description: "General intelligence"),
                AIModel(id: "deepseek-reasoner", name: "DeepSeek-R1", provider: .deepseek, description: "Chain-of-thought reasoning")
            ]
        case .ollama:
            return [
                AIModel(id: "llama3", name: "Llama 3", provider: .ollama, description: "Local Ollama model"),
                AIModel(id: "mistral", name: "Mistral 7B", provider: .ollama, description: "Local Ollama model"),
                AIModel(id: "deepseek-r1", name: "DeepSeek R1", provider: .ollama, description: "Local Ollama reasoning"),
                AIModel(id: "qwen2.5", name: "Qwen 2.5", provider: .ollama, description: "Local Ollama Qwen")
            ]
        }
    }
}
