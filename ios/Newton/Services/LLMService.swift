//
//  LLMService.swift
//  Newton
//
//  Created for Newton iOS.
//  Multi-provider streaming client with Multimodal Vision and Singularity prompt injection.
//

import Foundation
import UIKit

public final class LLMService {
    public static let shared = LLMService()
    
    private init() {}
    
    public func streamCompletion(
        messages: [Message],
        provider: AIProvider,
        modelId: String,
        baseUrl: String,
        apiKey: String,
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        systemPrompt: String = SettingsManager.singularitySystemPrompt
    ) -> AsyncThrowingStream<String, Error> {
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = constructEndpointURL(provider: provider, baseUrl: baseUrl) else {
                        throw NSError(domain: "LLMService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API Base URL: \(baseUrl)"])
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 120
                    
                    setupAuthHeaders(request: &request, provider: provider, apiKey: apiKey)
                    
                    let payloadData = try constructPayload(
                        provider: provider,
                        modelId: modelId,
                        messages: messages,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        systemPrompt: systemPrompt
                    )
                    request.httpBody = payloadData
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NSError(domain: "LLMService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        throw NSError(domain: "LLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errorBody)"])
                    }
                    
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        
                        if trimmed == "data: [DONE]" || trimmed == "[DONE]" {
                            break
                        }
                        
                        if trimmed.hasPrefix("data: ") || trimmed.hasPrefix("data:") {
                            let jsonStr = trimmed.hasPrefix("data: ") ? String(trimmed.dropFirst(6)) : String(trimmed.dropFirst(5))
                            
                            if let token = parseToken(from: jsonStr, provider: provider) {
                                continuation.yield(token)
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    private func constructEndpointURL(provider: AIProvider, baseUrl: String) -> URL? {
        let cleanBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        switch provider {
        case .anthropic:
            return URL(string: "https://api.anthropic.com/v1/messages")
        case .gemini:
            return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
        case .ollama:
            return URL(string: "\(cleanBase)/api/chat")
        default:
            if cleanBase.hasSuffix("/chat/completions") {
                return URL(string: cleanBase)
            } else if cleanBase.hasSuffix("/v1") {
                return URL(string: "\(cleanBase)/chat/completions")
            } else {
                return URL(string: "\(cleanBase)/v1/chat/completions")
            }
        }
    }
    
    private func setupAuthHeaders(request: inout URLRequest, provider: AIProvider, apiKey: String) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        
        switch provider {
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .openrouter:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("https://newton.ai", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Newton iOS", forHTTPHeaderField: "X-Title")
        default:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func constructPayload(
        provider: AIProvider,
        modelId: String,
        messages: [Message],
        temperature: Double,
        maxTokens: Int,
        systemPrompt: String
    ) throws -> Data {
        
        let effectiveSystemPrompt = systemPrompt.isEmpty ? SettingsManager.singularitySystemPrompt : systemPrompt
        
        if provider == .anthropic {
            var formattedMessages: [[String: Any]] = []
            for msg in messages where msg.role != .system {
                let role = msg.role == .user ? "user" : "assistant"
                
                if let imgDataUrl = msg.imageUrl, imgDataUrl.hasPrefix("data:image/") {
                    var mediaType = "image/jpeg"
                    var base64Data = imgDataUrl
                    if let commaIdx = imgDataUrl.firstIndex(of: ",") {
                        let header = String(imgDataUrl[..<commaIdx])
                        base64Data = String(imgDataUrl[imgDataUrl.index(after: commaIdx)...])
                        if header.contains("image/png") { mediaType = "image/png" }
                        else if header.contains("image/webp") { mediaType = "image/webp" }
                    }
                    
                    let contentArray: [[String: Any]] = [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mediaType,
                                "data": base64Data
                            ]
                        ],
                        [
                            "type": "text",
                            "text": msg.content.isEmpty ? "Analyze this content." : msg.content
                        ]
                    ]
                    formattedMessages.append(["role": role, "content": contentArray])
                } else {
                    formattedMessages.append(["role": role, "content": msg.content])
                }
            }
            
            var payload: [String: Any] = [
                "model": modelId,
                "messages": formattedMessages,
                "max_tokens": maxTokens,
                "temperature": temperature,
                "stream": true,
                "system": effectiveSystemPrompt
            ]
            return try JSONSerialization.data(withJSONObject: payload)
            
        } else {
            // OpenAI & OpenAI Compatible format (OpenRouter, Custom AIEndpoints, Groq, Ollama, DeepSeek)
            var formattedMessages: [[String: Any]] = []
            
            formattedMessages.append([
                "role": "system",
                "content": effectiveSystemPrompt
            ])
            
            for (index, msg) in messages.enumerated() {
                let role = msg.role.rawValue
                var textContent = msg.content
                
                // Reinforce Singularity identity & Orbits capability on initial user prompt for local proxy compatibility
                if index == 0 && msg.role == .user {
                    textContent = "[IDENTITY & ORBITS: You are Newton (Singularity). You have the tool [ORBIT:generate_image]{\"prompt\": \"...\"}[/ORBIT] to create images. If the user asks for an image, invoke it directly.]\n\n\(textContent)"
                }
                
                if let imgDataUrl = msg.imageUrl, !imgDataUrl.isEmpty {
                    let contentArray: [[String: Any]] = [
                        ["type": "text", "text": textContent.isEmpty ? "Describe and analyze this content." : textContent],
                        ["type": "image_url", "image_url": ["url": imgDataUrl]]
                    ]
                    formattedMessages.append(["role": role, "content": contentArray])
                } else {
                    formattedMessages.append(["role": role, "content": textContent])
                }
            }
            
            let payload: [String: Any] = [
                "model": modelId,
                "messages": formattedMessages,
                "temperature": temperature,
                "max_tokens": maxTokens,
                "stream": true
            ]
            return try JSONSerialization.data(withJSONObject: payload)
        }
    }
    
    private func parseToken(from jsonString: String, provider: AIProvider) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if provider == .anthropic {
            let type = json["type"] as? String ?? ""
            if type == "content_block_delta" {
                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    return text
                }
            }
            return nil
        }
        
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first {
            
            if let delta = firstChoice["delta"] as? [String: Any] {
                if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                    return "<think>\(reasoning)</think>"
                }
                if let content = delta["content"] as? String {
                    return content
                }
            }
            
            if let text = firstChoice["text"] as? String {
                return text
            }
        }
        
        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        if let response = json["response"] as? String {
            return response
        }
        
        return nil
    }
}
