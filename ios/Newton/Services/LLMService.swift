//
//  LLMService.swift
//  Newton
//
//  NWTN-native streaming client.
//  Sends: { prompt, history, attachments, stream: true }
//  Receives SSE: data: {"delta":"..."} … data: {"done":true, "reply":"..."} data: [DONE]
//

import Foundation
import UIKit

// MARK: - NWTN attachment type
public struct NWTNAttachment: Encodable {
    public let type: String       // "image" | "pdf" | "text" | "file" | "ref" | "url"
    public let data: String?      // base64/data-uri/url/text
    public let id: String?        // for "ref" attachments (fl_...)
    public let name: String?

    public init(type: String, data: String? = nil, id: String? = nil, name: String? = nil) {
        self.type = type
        self.data = data
        self.id   = id
        self.name = name
    }
}

// MARK: - LLMService
public final class LLMService {
    public static let shared = LLMService()
    private init() {}

    /// Full NWTN streaming call.
    /// - Parameters:
    ///   - messages: Conversation history (role: user|assistant|system, content: String)
    ///   - systemPrompt: Injected as a leading system message in history
    ///   - attachments: Typed list for images, PDFs, refs, URLs
    /// - Returns: AsyncThrowingStream of text deltas
    public func streamCompletion(
        messages: [Message],
        provider: AIProvider? = nil,        // ignored — always NWTN
        modelId: String? = nil,             // ignored — always Singularity
        baseUrl: String? = nil,             // ignored — always NWTN upstream
        apiKey: String? = nil,              // ignored — always from AuthManager
        temperature: Double = 0.7,          // ignored by NWTN (forward-compat param)
        maxTokens: Int = 4096,              // ignored by NWTN (forward-compat param)
        systemPrompt: String = SettingsManager.singularitySystemPrompt,
        attachments: [NWTNAttachment] = []
    ) -> AsyncThrowingStream<String, Error> {

        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let nwtnKey = AuthManager.shared.nwtnKey
                    guard !nwtnKey.isEmpty else {
                        throw NSError(domain: "LLMService", code: 401,
                                      userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please log in."])
                    }

                    let endpoint = SettingsManager.nwtnBaseURL + "/chat"
                    guard let url = URL(string: endpoint) else {
                        throw NSError(domain: "LLMService", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid NWTN endpoint: \(endpoint)"])
                    }

                    // Build NWTN history from messages
                    // NWTN history = array of {role, content} — no system role in list;
                    // system prompt goes as first history entry with role "system"
                    var history: [[String: String]] = []

                    // Memory injection into system prompt
                    var effectiveSystem = systemPrompt.isEmpty ? SettingsManager.singularitySystemPrompt : systemPrompt
                    let memoryFacts = MemoryManager.shared.formattedMemoryPrompt()
                    effectiveSystem += """


                    ==================================================
                    PERSISTENT USER LONG-TERM MEMORY SYSTEM
                    ==================================================
                    - You POSSESS an active persistent memory system across all sessions.
                    - Current stored user memories:
                    \(memoryFacts.isEmpty ? "(No facts stored yet. When the user tells you about themselves, invoke <orbit:save_memory>{\"fact\": \"...\"}</orbit:save_memory>.)" : memoryFacts)
                    """

                    history.append(["role": "system", "content": effectiveSystem])

                    // Append conversation messages (skip system role — already injected above)
                    for msg in messages where msg.role != .system {
                        history.append([
                            "role":    msg.role == .user ? "user" : "assistant",
                            "content": msg.content
                        ])
                    }

                    // The last user message IS the prompt
                    let prompt = messages.last(where: { $0.role == .user })?.content ?? ""

                    // Build attachments array — include image from last user message if present
                    var allAttachments: [[String: String?]] = attachments.map { att in
                        var d: [String: String?] = ["type": att.type]
                        if let v = att.data { d["data"] = v }
                        if let v = att.id   { d["id"]   = v }
                        if let v = att.name { d["name"] = v }
                        return d
                    }

                    // Auto-detect image from last user message
                    if let lastUserMsg = messages.last(where: { $0.role == .user }),
                       let imgDataUrl = lastUserMsg.imageUrl, !imgDataUrl.isEmpty {
                        let alreadyIncluded = allAttachments.contains { ($0["type"] ?? "") == "image" }
                        if !alreadyIncluded {
                            allAttachments.append(["type": "image", "data": imgDataUrl, "name": "image.png"])
                        }
                    }

                    // Build payload
                    var payload: [String: Any] = [
                        "prompt":  prompt,
                        "history": history,
                        "stream":  true
                    ]
                    if !allAttachments.isEmpty {
                        payload["attachments"] = allAttachments
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(nwtnKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("Newton-iOS/2.0", forHTTPHeaderField: "User-Agent")
                    request.timeoutInterval = 300
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw NSError(domain: "LLMService", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                    }

                    guard (200...299).contains(http.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        // Try to extract NWTN error message
                        if let data = body.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let err = json["error"] as? [String: Any],
                           let msg = err["message"] as? String {
                            throw NSError(domain: "LLMService", code: http.statusCode,
                                          userInfo: [NSLocalizedDescriptionKey: msg])
                        }
                        throw NSError(domain: "LLMService", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
                    }

                    // Parse NWTN SSE stream
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }

                        // End of stream
                        if trimmed == "data: [DONE]" || trimmed == "[DONE]" { break }

                        // Strip "data: " prefix
                        let jsonStr: String
                        if trimmed.hasPrefix("data: ") {
                            jsonStr = String(trimmed.dropFirst(6))
                        } else if trimmed.hasPrefix("data:") {
                            jsonStr = String(trimmed.dropFirst(5))
                        } else {
                            continue
                        }

                        guard let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        // NWTN delta event
                        if let delta = json["delta"] as? String {
                            continuation.yield(delta)
                        }

                        // NWTN done event — final reply already streamed token by token
                        if let done = json["done"] as? Bool, done { break }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Non-streaming helper (title generation etc.)
    public func complete(
        prompt: String,
        task: String = "title",
        apiKey: String? = nil
    ) async throws -> String {
        let nwtnKey = apiKey ?? AuthManager.shared.nwtnKey
        guard !nwtnKey.isEmpty else { throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) }

        let endpoint = SettingsManager.nwtnBaseURL + "/chat"
        guard let url = URL(string: endpoint) else { throw NSError(domain: "LLMService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad URL"]) }

        let payload: [String: Any] = ["prompt": prompt, "task": task, "stream": false]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(nwtnKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["reply"] as? String ?? ""
    }
}
