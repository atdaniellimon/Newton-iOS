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
    case desktopStatus = "desktop:status"
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
    case aiTool = "ai:tool"
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
    public let tool: String?
    public let toolOutput: String?
}

// MARK: - CloudChatService

public final class CloudChatService: ObservableObject {
    public static let shared = CloudChatService()
    
    private let baseURL = "https://api.newton.daniellimon.uk"
    private var globalSyncTask: Task<Void, Never>? = nil
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncError: String? = nil
    @Published public var desktopStatus: RemoteDesktopStatus? = nil
    @Published public var desktopWorkspaces: [RemoteWorkspaceItem] = []
    
    private var hostPresenceTask: Task<Void, Never>? = nil
    
    private init() {
        startHostPresenceMonitoring()
    }
    
    public func startHostPresenceMonitoring() {
        hostPresenceTask?.cancel()
        hostPresenceTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                if AuthManager.shared.isLoggedIn {
                    await self.refreshHostStatus()
                }
                try? await Task.sleep(nanoseconds: 8_000_000_000) // Poll every 8s
            }
        }
    }
    
    @MainActor
    public func refreshHostStatus() async {
        do {
            let status = try await fetchDesktopStatus()
            self.desktopStatus = status
            if status.online {
                let ws = try await fetchDesktopWorkspaces()
                self.desktopWorkspaces = ws
            }
        } catch {
            // If request fails or network drops, don't crash
            if self.desktopStatus?.online == true {
                self.desktopStatus = RemoteDesktopStatus(online: false, workspaces_count: 0, last_seen: nil, active_workspace: nil)
            }
        }
    }
    
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
                    if let imgUsedHdr = http.value(forHTTPHeaderField: "X-Daily-Images-Used"), let used = Int(imgUsedHdr) {
                        DispatchQueue.main.async {
                            AuthManager.shared.tier.dailyImagesUsed = used
                        }
                    }
                    if let imgLimitHdr = http.value(forHTTPHeaderField: "X-Daily-Images-Limit") {
                        DispatchQueue.main.async {
                            AuthManager.shared.tier.dailyImagesLimit = imgLimitHdr
                        }
                    }
                    
                    guard http.statusCode == 200 else {
                        var errText = ""
                        for try await byte in bytes {
                            errText.append(Character(UnicodeScalar(byte)))
                            if errText.count > 2048 { break }
                        }
                        
                        var humanError = "Server error (\(http.statusCode)): \(errText)"
                        if let data = errText.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let errObj = json["error"] as? [String: Any],
                               let msg = errObj["message"] as? String {
                                humanError = msg
                            } else if let detail = json["detail"] as? String {
                                humanError = detail
                            }
                        }
                        throw NSError(domain: "CloudChatService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: humanError])
                    }
                    
                    var buffer = ""
                    var utf8Decoder = Unicode.UTF8()
                    var utf8Buffer: [UInt8] = []
                    
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        utf8Buffer.append(byte)
                        
                        if let decodedString = String(bytes: utf8Buffer, encoding: .utf8) {
                            buffer.append(decodedString)
                            utf8Buffer.removeAll(keepingCapacity: true)
                        } else if utf8Buffer.count > 16 {
                            // If invalid sequence after several bytes, force decode and clear
                            buffer.append(String(decoding: utf8Buffer, as: UTF8.self))
                            utf8Buffer.removeAll(keepingCapacity: true)
                        }
                        
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
                                        if let reply = json["reply"] as? String, !reply.isEmpty {
                                            continuation.yield(reply)
                                        }
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
                    var utf8Buffer: [UInt8] = []
                    
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        utf8Buffer.append(byte)
                        if let decodedString = String(bytes: utf8Buffer, encoding: .utf8) {
                            buffer.append(decodedString)
                            utf8Buffer.removeAll(keepingCapacity: true)
                        } else if utf8Buffer.count > 16 {
                            buffer.append(String(decoding: utf8Buffer, as: UTF8.self))
                            utf8Buffer.removeAll(keepingCapacity: true)
                        }
                        
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
                                    case "chat:created":    evType = .chatCreated
                                    case "chat:updated":    evType = .chatUpdated
                                    case "chat:deleted":    evType = .chatDeleted
                                    case "desktop:status":  evType = .desktopStatus
                                    default:                evType = .unknown
                                    }
                                    
                                    if evType == .desktopStatus {
                                        let isOnline = json["online"] as? Bool ?? true
                                        let count = json["workspaces_count"] as? Int ?? 0
                                        let lastSeen = json["timestamp"] as? Double ?? Date().timeIntervalSince1970
                                        DispatchQueue.main.async {
                                            self.desktopStatus = RemoteDesktopStatus(
                                                online: isOnline,
                                                workspaces_count: count,
                                                last_seen: lastSeen,
                                                active_workspace: nil
                                            )
                                        }
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
                    var utf8Buffer: [UInt8] = []
                    
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        utf8Buffer.append(byte)
                        if let decodedString = String(bytes: utf8Buffer, encoding: .utf8) {
                            buffer.append(decodedString)
                            utf8Buffer.removeAll(keepingCapacity: true)
                        } else if utf8Buffer.count > 16 {
                            buffer.append(String(decoding: utf8Buffer, as: UTF8.self))
                            utf8Buffer.removeAll(keepingCapacity: true)
                        }
                        
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
                                    case "ai:tool":     evType = .aiTool
                                    case "chat:updated":evType = .chatUpdated
                                    case "chat:deleted":evType = .chatDeleted
                                    default:            evType = .unknown
                                    }
                                    
                                    let peerEvent = ChatPeerEvent(
                                        event: evType,
                                        messageId: json["id"] as? String ?? json["message_id"] as? String,
                                        role: json["role"] as? String,
                                        delta: json["delta"] as? String,
                                        content: json["content"] as? String,
                                        tool: json["tool"] as? String,
                                        toolOutput: json["output"] as? String
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
    
    // MARK: - 9. Desktop Remote Control API (Mac ⟷ iPhone Bridge)
    
    public struct RemoteDesktopStatus: Codable {
        public let online: Bool
        public let workspaces_count: Int
        public let last_seen: Double?
        public let active_workspace: String?
    }
    
    public struct RemoteWorkspaceChat: Codable, Identifiable {
        public let id: String
        public let title: String
        public let created_at: Double?
        public let messages: [[String: String]]?
    }
    
    public struct RemoteWorkspaceItem: Codable, Identifiable {
        public var id: String { path }
        public let name: String
        public let path: String
        public let hasGit: Bool?
        public let branch: String?
        public let chats: [RemoteWorkspaceChat]?
    }
    
    public struct RemoteWorkspacesResponse: Codable {
        public let workspaces: [RemoteWorkspaceItem]?
        public let last_updated: Double?
    }
    
    public struct RemoteDispatchResponse: Codable {
        public let success: Bool
        public let sessionId: String?
        public let chatId: String?
        public let status: String?
        public let message: String?
    }
    
    public struct RemoteStepEvent {
        public let stepType: String
        public let chatId: String?
        public let workspacePath: String?
        public let toolName: String?
        public let message: String?
        public let stdout: String?
        public let stderr: String?
        public let timestamp: Date
    }
    
    public func fetchDesktopStatus() async throws -> RemoteDesktopStatus {
        let req = try makeRequest(endpoint: "/nwtn/desktop/status")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "CloudChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get desktop status"])
        }
        return try JSONDecoder().decode(RemoteDesktopStatus.self, from: data)
    }
    
    public func fetchDesktopWorkspaces() async throws -> [RemoteWorkspaceItem] {
        let req = try makeRequest(endpoint: "/nwtn/desktop/workspaces")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "CloudChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch desktop workspaces"])
        }
        let decoded = try JSONDecoder().decode(RemoteWorkspacesResponse.self, from: data)
        return decoded.workspaces ?? []
    }
    
    public func dispatchDesktopCommand(workspacePath: String, chatId: String? = nil, task: String, model: String = "Singularity-Matrix") async throws -> RemoteDispatchResponse {
        var body: [String: Any] = [
            "workspacePath": workspacePath,
            "task": task,
            "model": model
        ]
        if let cId = chatId {
            body["chatId"] = cId
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let req = try makeRequest(endpoint: "/nwtn/desktop/dispatch", method: "POST", body: bodyData)
        let (data, response) = try await URLSession.shared.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let errStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudChatService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Dispatch failed: \(errStr)"])
        }
        return try JSONDecoder().decode(RemoteDispatchResponse.self, from: data)
    }
    
    public func cancelDesktopCommand(sessionId: String? = nil) async throws {
        var endpoint = "/nwtn/desktop/cancel"
        if let s = sessionId { endpoint += "?sessionId=\(s)" }
        let req = try makeRequest(endpoint: endpoint, method: "POST")
        _ = try await URLSession.shared.data(for: req)
    }
    
    public func streamDesktopSession() -> AsyncStream<RemoteStepEvent> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    var req = try self.makeRequest(endpoint: "/nwtn/desktop/session/stream")
                    req.timeoutInterval = 86400
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish()
                        return
                    }
                    
                    var currentEventType: String? = nil
                    var buffer = ""
                    var utf8Buffer: [UInt8] = []
                    
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        utf8Buffer.append(byte)
                        if let decodedString = String(bytes: utf8Buffer, encoding: .utf8) {
                            buffer.append(decodedString)
                            utf8Buffer.removeAll(keepingCapacity: true)
                        } else if utf8Buffer.count > 16 {
                            buffer.append(String(decoding: utf8Buffer, as: UTF8.self))
                            utf8Buffer.removeAll(keepingCapacity: true)
                        }
                        
                        while let lineEnd = buffer.range(of: "\n") {
                            let line = String(buffer[..<lineEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = String(buffer[lineEnd.upperBound...])
                            
                            if line.hasPrefix("event: ") {
                                currentEventType = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                            } else if line.hasPrefix("data: ") {
                                let dataStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                                if let data = dataStr.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    
                                    let step = RemoteStepEvent(
                                        stepType: json["stepType"] as? String ?? currentEventType ?? "step",
                                        chatId: json["chatId"] as? String,
                                        workspacePath: json["workspacePath"] as? String,
                                        toolName: json["toolName"] as? String,
                                        message: json["message"] as? String,
                                        stdout: json["stdout"] as? String,
                                        stderr: json["stderr"] as? String,
                                        timestamp: Date()
                                    )
                                    continuation.yield(step)
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

