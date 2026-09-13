//
//  CloudChatService.swift
//  Newton
//
//  Newton Labs Gateway v2.2.0 — Multi-Device Cloud Chat & Synchronization Service
//  Handles:
//  - GET /nwtn/chats (list cloud chats)
//  - POST /nwtn/chats (create cloud chat)
//  - GET /nwtn/chats/{id} (fetch chat details)
//  - PATCH /nwtn/chats/{id} (update title, is_pinned, model)
//  - DELETE /nwtn/chats/{id} (delete chat)
//  - GET /nwtn/chats/{id}/messages (fetch message history)
//  - POST /nwtn/chats/{id}/messages?stream=true (send message with real-time SSE stream)
//  - GET /nwtn/sync/events (global SSE sync stream for account-level chat lifecycle)
//  - GET /nwtn/chats/{id}/events (active chat SSE stream for live peer collaboration)
//

import Foundation
import Combine

// MARK: - Cloud Models

public struct CloudChatDTO: Codable {
    public let id: String
    public let title: String
    public let model: String?
    public let system_prompt: String?
    public let is_pinned: Int?
    public let created_at: Double?
    public let updated_at: Double?
    public let last_message: String?
    public let message_count: Int?
}

public struct CloudChatListResponse: Codable {
    public let chats: [CloudChatDTO]?
    public let count: Int?
}

public struct CloudSingleChatResponse: Codable {
    public let chat: CloudChatDTO?
}

public struct CloudMessageDTO: Codable {
    public let id: String
    public let chat_id: String?
    public let role: String
    public let content: String
    public let model: String?
    public let created_at: Double?
}

public struct CloudMessageListResponse: Codable {
    public let messages: [CloudMessageDTO]?
}

// MARK: - Sync Event Types

public enum CloudSyncEventType: String {
    case chatCreated = "chat:created"
    case chatUpdated = "chat:updated"
    case chatDeleted = "chat:deleted"
    case unknown
}

public struct CloudSyncEvent {
    public let event: CloudSyncEventType
    public let chatId: String?
    public let title: String?
    public let isPinned: Bool?
    public let model: String?
    public let updatedAt: Date?
}

public enum ChatPeerEventType: String {
    case messageNew = "message:new"
    case aiStart = "ai:start"
    case aiDelta = "ai:delta"
    case aiDone = "ai:done"
    case chatUpdated = "chat:updated"
    case chatDeleted = "chat:deleted"
    case unknown
}

public struct ChatPeerEvent {
    public let event: ChatPeerEventType
    public let messageId: String?
    public let role: String?
    public let delta: String?
    public let content: String?
}

// MARK: - CloudChatService

public final class CloudChatService: ObservableObject {
    public static let shared = CloudChatService()
    
    private let baseURL = "https://api.newton.daniellimon.uk"
    private var globalSyncTask: Task<Void, Never>? = nil
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncError: String? = nil
    
    private init() {}
    
    // MARK: - Request Helper
    
    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        let key = AuthManager.shared.nwtnKey
        guard !key.isEmpty else {
            throw NSError(domain: "CloudChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required."])
        }
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NSError(domain: "CloudChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint: \(endpoint)"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("Newton-iOS/2.2.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60
        request.httpBody = body
        return request
    }
    
    // MARK: - 1. List Chats: GET /nwtn/chats
    
    public func fetchChats(limit: Int = 100, offset: Int = 0) async throws -> [Conversation] {
        let req = try makeRequest(endpoint: "/nwtn/chats?limit=\(limit)&offset=\(offset)")
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "CloudChatService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudChatService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch chats (\(http.statusCode)): \(bodyStr)"])
        }
        
        let decoded = try JSONDecoder().decode(CloudChatListResponse.self, from: data)
        guard let remoteChats = decoded.chats else { return [] }
        
        return remoteChats.map { c in
            let cDate = c.created_at.map { Date(timeIntervalSince1970: $0) } ?? Date()
            let uDate = c.updated_at.map { Date(timeIntervalSince1970: $0) } ?? cDate
            return Conversation(
                id: c.id,
                title: c.title,
                messages: [],
                isPinned: (c.is_pinned ?? 0) == 1,
                isGhost: false,
                modelId: c.model ?? SettingsManager.shared.currentModelId,
                createdAt: cDate,
                updatedAt: uDate
            )
        }
    }
    
    // MARK: - 2. Create Chat: POST /nwtn/chats
    
    public func createChat(title: String, model: String? = nil, systemPrompt: String? = nil) async throws -> Conversation {
        var bodyDict: [String: Any] = [
            "title": title,
            "model": model ?? SettingsManager.shared.currentModelId
        ]
        if let sp = systemPrompt, !sp.isEmpty {
            bodyDict["system_prompt"] = sp
        }
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        let req = try makeRequest(endpoint: "/nwtn/chats", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...201).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudChatService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create chat: \(bodyStr)"])
        }
        
        let decoded = try JSONDecoder().decode(CloudSingleChatResponse.self, from: data)
        guard let c = decoded.chat else {
            throw NSError(domain: "CloudChatService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Malformed server response for chat creation"])
        }
        
        let cDate = c.created_at.map { Date(timeIntervalSince1970: $0) } ?? Date()
        let uDate = c.updated_at.map { Date(timeIntervalSince1970: $0) } ?? cDate
        return Conversation(
            id: c.id,
            title: c.title,
            messages: [],
            isPinned: (c.is_pinned ?? 0) == 1,
            isGhost: false,
            modelId: c.model ?? SettingsManager.shared.currentModelId,
            createdAt: cDate,
            updatedAt: uDate
        )
    }
    
    // MARK: - 3. Update Chat: PATCH /nwtn/chats/{id}
    
    public func updateChat(id: String, title: String? = nil, isPinned: Bool? = nil, model: String? = nil) async throws {
        guard !id.isEmpty else { return }
        var bodyDict: [String: Any] = [:]
        if let t = title { bodyDict["title"] = t }
        if let p = isPinned { bodyDict["is_pinned"] = p ? 1 : 0 }
        if let m = model { bodyDict["model"] = m }
        
        guard !bodyDict.isEmpty else { return }
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        let req = try makeRequest(endpoint: "/nwtn/chats/\(id)", method: "PATCH", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudChatService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update chat: \(bodyStr)"])
        }
    }
    
    // MARK: - 4. Delete Chat: DELETE /nwtn/chats/{id}
    
    public func deleteChat(id: String) async throws {
        guard !id.isEmpty else { return }
        let req = try makeRequest(endpoint: "/nwtn/chats/\(id)", method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudChatService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete chat: \(bodyStr)"])
        }
    }
    
    // MARK: - 5. Fetch Messages: GET /nwtn/chats/{id}/messages
    
    public func fetchMessages(chatId: String, limit: Int = 100) async throws -> [Message] {
        guard !chatId.isEmpty else { return [] }
        let req = try makeRequest(endpoint: "/nwtn/chats/\(chatId)/messages?limit=\(limit)")
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudChatService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch messages: \(bodyStr)"])
        }
        
        let decoded = try JSONDecoder().decode(CloudMessageListResponse.self, from: data)
        guard let remoteMsgs = decoded.messages else { return [] }
        
        return remoteMsgs.map { m in
            let date = m.created_at.map { Date(timeIntervalSince1970: $0) } ?? Date()
            let role: MessageRole
            switch m.role.lowercased() {
            case "user": role = .user
            case "system": role = .system
            default: role = .assistant
            }
            return Message(
                id: m.id,
                role: role,
                content: m.content,
                createdAt: date,
                isStreaming: false
            )
        }
    }
    
    // MARK: - 6. Stream Chat Message: POST /nwtn/chats/{id}/messages?stream=true
    
    public func streamChatMessage(
        chatId: String,
        prompt: String,
        model: String? = nil,
        attachments: [NWTNAttachment] = []
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var bodyDict: [String: Any] = [
                        "prompt": prompt,
                        "model": model ?? SettingsManager.shared.currentModelId
                    ]
                    
                    var allAttachments: [[String: String?]] = attachments.map { att in
                        var d: [String: String?] = ["type": att.type]
                        if let v = att.data { d["data"] = v }
                        if let v = att.id { d["id"] = v }
                        if let v = att.name { d["name"] = v }
                        return d
                    }
                    if !allAttachments.isEmpty {
                        bodyDict["attachments"] = allAttachments
                    }
                    
                    let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
                    var req = try self.makeRequest(endpoint: "/nwtn/chats/\(chatId)/messages?stream=true", method: "POST", body: bodyData)
                    req.timeoutInterval = 300
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw NSError(domain: "CloudChatService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                    }
                    
                    if let creditsHdr = http.value(forHTTPHeaderField: "X-Credits-Left"), let cred = Int(creditsHdr) {
                        DispatchQueue.main.async {
                            AuthManager.shared.updateCreditsFromStream(cred)
                        }
                    }
                    
                    guard http.statusCode == 200 else {
                        var errText = ""
                        for try await byte in bytes {
                            errText.append(Character(UnicodeScalar(byte)))
                            if errText.count > 1024 { break }
                        }
                        throw NSError(domain: "CloudChatService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(http.statusCode)): \(errText)"])
                    }
                    
                    var buffer = ""
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        while let lineEnd = buffer.range(of: "\n") {
                            let line = String(buffer[..<lineEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = String(buffer[lineEnd.upperBound...])
                            
                            if line.hasPrefix("data: ") {
                                let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                                if payload == "[DONE]" {
                                    continuation.finish()
                                    return
                                }
                                
                                if let data = payload.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    if let credits = json["credits_left"] as? Int {
                                        DispatchQueue.main.async {
                                            AuthManager.shared.updateCreditsFromStream(credits)
                                        }
                                    }
                                    
                                    if let delta = json["delta"] as? String {
                                        continuation.yield(delta)
                                    } else if let errorMsg = json["error"] as? String {
                                        throw NSError(domain: "CloudChatService", code: -4, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                                    }
                                    
                                    if let done = json["done"] as? Bool, done {
                                        continuation.finish()
                                        return
                                    }
                                }
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
    
    // MARK: - 7. Global Real-Time Sync Stream: GET /nwtn/sync/events
    
    public func startGlobalSyncListener(onEvent: @escaping (CloudSyncEvent) -> Void) {
        stopGlobalSyncListener()
        
        globalSyncTask = Task {
            while !Task.isCancelled {
                do {
                    guard AuthManager.shared.isLoggedIn else {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        continue
                    }
                    
                    var req = try self.makeRequest(endpoint: "/nwtn/sync/events")
                    req.timeoutInterval = 86400
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                        continue
                    }
                    
                    var currentEventType: String? = nil
                    var buffer = ""
                    
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        while let lineEnd = buffer.range(of: "\n") {
                            let line = String(buffer[..<lineEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = String(buffer[lineEnd.upperBound...])
                            
                            if line.hasPrefix("event: ") {
                                currentEventType = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                            } else if line.hasPrefix("data: ") {
                                let dataStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                                if let eventTypeStr = currentEventType,
                                   let data = dataStr.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    
                                    let evType: CloudSyncEventType
                                    switch eventTypeStr {
                                    case "chat:created": evType = .chatCreated
                                    case "chat:updated": evType = .chatUpdated
                                    case "chat:deleted": evType = .chatDeleted
                                    default:             evType = .unknown
                                    }
                                    
                                    let chatId = json["id"] as? String ?? json["chat_id"] as? String
                                    let title = json["title"] as? String
                                    let isPinned = (json["is_pinned"] as? Int).map { $0 == 1 } ?? (json["is_pinned"] as? Bool)
                                    let model = json["model"] as? String
                                    let updatedAt = (json["updated_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
                                    
                                    let syncEv = CloudSyncEvent(
                                        event: evType,
                                        chatId: chatId,
                                        title: title,
                                        isPinned: isPinned,
                                        model: model,
                                        updatedAt: updatedAt
                                    )
                                    
                                    DispatchQueue.main.async {
                                        onEvent(syncEv)
                                    }
                                }
                                currentEventType = nil
                            }
                        }
                    }
                } catch {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }
    }
    
    public func stopGlobalSyncListener() {
        globalSyncTask?.cancel()
        globalSyncTask = nil
    }
    
    // MARK: - 8. Active Chat Peer Event Stream: GET /nwtn/chats/{id}/events
    
    public func streamChatEvents(chatId: String) -> AsyncStream<ChatPeerEvent> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    guard !chatId.isEmpty else {
                        continuation.finish()
                        return
                    }
                    
                    var req = try self.makeRequest(endpoint: "/nwtn/chats/\(chatId)/events")
                    req.timeoutInterval = 86400
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish()
                        return
                    }
                    
                    var currentEventType: String? = nil
                    var buffer = ""
                    
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        while let lineEnd = buffer.range(of: "\n") {
                            let line = String(buffer[..<lineEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = String(buffer[lineEnd.upperBound...])
                            
                            if line.hasPrefix("event: ") {
                                currentEventType = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                            } else if line.hasPrefix("data: ") {
                                let dataStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                                if let eventTypeStr = currentEventType,
                                   let data = dataStr.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    
                                    let evType: ChatPeerEventType
                                    switch eventTypeStr {
                                    case "message:new": evType = .messageNew
                                    case "ai:start":    evType = .aiStart
                                    case "ai:delta":    evType = .aiDelta
                                    case "ai:done":     evType = .aiDone
                                    case "chat:updated":evType = .chatUpdated
                                    case "chat:deleted":evType = .chatDeleted
                                    default:            evType = .unknown
                                    }
                                    
                                    let peerEvent = ChatPeerEvent(
                                        event: evType,
                                        messageId: json["id"] as? String ?? json["message_id"] as? String,
                                        role: json["role"] as? String,
                                        delta: json["delta"] as? String,
                                        content: json["content"] as? String
                                    )
                                    
                                    continuation.yield(peerEvent)
                                }
                                currentEventType = nil
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
