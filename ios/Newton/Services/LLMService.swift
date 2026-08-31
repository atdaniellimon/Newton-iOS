//
//  LLMService.swift
//  Newton
//
//  Created for Newton iOS.
//  High-performance Server-Sent Events (SSE) streaming engine with Multimodal Vision support.
//

import Foundation

public final class LLMService {
    public static let shared = LLMService()
    
    private init() {}
    
    /// Stream completions token-by-token using AsyncThrowingStream with Vision Multimodal support
    public func streamCompletion(
        messages: [Message],
        provider: AIProvider,
        modelId: String,
        baseUrl: String,
        apiKey: String,
        temperature: Double,
        maxTokens: Int,
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = constructEndpointURL(provider: provider, baseUrl: baseUrl) else {
                        throw LLMError.invalidEndpoint
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 90
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    
                    // Setup Authentication Headers
                    setupAuthHeaders(request: &request, provider: provider, apiKey: apiKey)
                    
                    // Construct Payload
                    let payloadData = try constructPayload(
                        provider: provider,
                        modelId: modelId,
                        messages: messages,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        systemPrompt: systemPrompt
                    )
                    request.httpBody = payloadData
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorBody = ""
                        for try await line in asyncBytes.lines {
                            errorBody += line + "\n"
                        }
                        throw LLMError.apiError(code: httpResponse.statusCode, message: errorBody)
                    }
                    
                    // Stream token-by-token parsing SSE lines
                    for try await line in asyncBytes.lines {
                        guard !Task.isCancelled else { break }
                        
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        
                        if trimmed == "data: [DONE]" || trimmed == "data:[DONE]" {
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
            // OpenAI, Groq, Mistral, OpenRouter, DeepSeek, Custom OpenAI Compatible
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
        case .openRouter:
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
        
        if provider == .anthropic {
            // Anthropic Messages API format
            var formattedMessages: [[String: Any]] = []
            for msg in messages where msg.role != .system {
                let role = msg.role == .user ? "user" : "assistant"
                
                if let imgDataUrl = msg.imageUrl, imgDataUrl.hasPrefix("data:image/") {
                    // Extract base64 and media type
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
                            "text": msg.content
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
                "stream": true
            ]
            if !systemPrompt.isEmpty {
                payload["system"] = systemPrompt
            }
            return try JSONSerialization.data(withJSONObject: payload)
            
        } else {
            // OpenAI & OpenAI Compatible format (OpenRouter, Groq, Gemini, Ollama, DeepSeek)
            var formattedMessages: [[String: Any]] = []
            
            if !systemPrompt.isEmpty {
                formattedMessages.append(["role": "system", "content": systemPrompt])
            }
            
            for msg in messages {
                let role = msg.role.rawValue
                
                if let imgDataUrl = msg.imageUrl, !imgDataUrl.isEmpty {
                    // Multimodal content array
                    let contentArray: [[String: Any]] = [
                        ["type": "text", "text": msg.content.isEmpty ? "Describe this image." : msg.content],
                        ["type": "image_url", "image_url": ["url": imgDataUrl]]
                    ]
                    formattedMessages.append(["role": role, "content": contentArray])
                } else {
                    formattedMessages.append(["role": role, "content": msg.content])
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
        
        // OpenAI format: choices[0].delta.content or delta.reasoning_content
        if let choices = json["choices"] as? [[String: Any]], let firstChoice = choices.first {
            if let delta = firstChoice["delta"] as? [String: Any] {
                if let content = delta["content"] as? String {
                    return content
                }
                if let reasoning = delta["reasoning_content"] as? String {
                    return "<think>\(reasoning)</think>"
                }
            }
        }
        
        // Ollama format: message.content
        if let message = json["message"] as? [String: Any], let content = message["content"] as? String {
            return content
        }
        
        return nil
    }
}

public enum LLMError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case apiError(code: Int, message: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid API Endpoint URL."
        case .invalidResponse:
            return "Invalid HTTP Response from AI server."
        case .apiError(let code, let msg):
            return "API Error (\(code)): \(msg)"
        }
    }
}
