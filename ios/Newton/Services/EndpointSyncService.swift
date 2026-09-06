//
//  EndpointSyncService.swift
//  Newton
//
//  Dynamic Remote Endpoint Synchronizer & Health-Check Service.
//  Fetches the active Cloudflare Tunnel endpoint dynamically from GitHub config.json / endpoint.txt,
//  tests server connectivity (/v1/models), and provides real-time health/latency metrics.
//

import Foundation
import Combine

public final class EndpointSyncService: ObservableObject {
    public static let shared = EndpointSyncService()
    
    private let remoteConfigUrl = "https://raw.githubusercontent.com/atdaniellimon/Newton-iOS/main/config.json"
    private let remoteEndpointTxtUrl = "https://raw.githubusercontent.com/atdaniellimon/Newton-iOS/main/endpoint.txt"
    
    @Published public var activeEndpoint: String = SettingsManager.hardcodedEndpoint
    @Published public var isServerOnline: Bool = false
    @Published public var serverLatencyMs: Int? = nil
    @Published public var availableModels: [String] = ["newton-singularity"]
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date? = nil
    @Published public var lastSyncError: String? = nil
    
    private init() {
        self.activeEndpoint = SettingsManager.shared.effectiveBaseUrl(for: .openaiCompatible)
        Task {
            await syncAndValidateEndpoint()
        }
    }
    
    /// Fetches the latest remote endpoint from GitHub and checks health
    @MainActor
    public func syncAndValidateEndpoint() async {
        isSyncing = true
        lastSyncError = nil
        
        var resolvedUrl: String? = nil
        
        // 1. Try fetching config.json
        if let configUrl = URL(string: "\(remoteConfigUrl)?t=\(Int(Date().timeIntervalSince1970))") {
            var request = URLRequest(url: configUrl)
            request.timeoutInterval = 3.0
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ep = json["endpoint"] as? String, !ep.isEmpty {
                resolvedUrl = ep.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 2. Fallback to endpoint.txt
        if resolvedUrl == nil, let txtUrl = URL(string: "\(remoteEndpointTxtUrl)?t=\(Int(Date().timeIntervalSince1970))") {
            var request = URLRequest(url: txtUrl)
            request.timeoutInterval = 3.0
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let str = String(data: data, encoding: .utf8) {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    resolvedUrl = trimmed
                }
            }
        }
        
        // Target URL to validate
        let targetUrl = resolvedUrl ?? SettingsManager.shared.customBaseUrl
        let cleanTarget = targetUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedTarget = cleanTarget.hasSuffix("/v1") ? cleanTarget : "\(cleanTarget)/v1"
        
        self.activeEndpoint = normalizedTarget
        SettingsManager.shared.customBaseUrl = normalizedTarget
        
        // 3. Health-Check: /v1/models
        await checkServerHealth(endpoint: normalizedTarget)
        
        self.isSyncing = false
        self.lastSyncDate = Date()
    }
    
    /// Tests server connectivity and measures latency
    @MainActor
    public func checkServerHealth(endpoint: String) async {
        let cleanBase = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let modelsUrlStr = cleanBase.hasSuffix("/models") ? cleanBase : "\(cleanBase)/models"
        
        guard let url = URL(string: modelsUrlStr) else {
            self.isServerOnline = false
            self.serverLatencyMs = nil
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.5
        let apiKey = SettingsManager.shared.currentApiKey
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.isServerOnline = true
                self.serverLatencyMs = latency
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArr = json["data"] as? [[String: Any]] {
                    let modelIds = dataArr.compactMap { $0["id"] as? String }
                    if !modelIds.isEmpty {
                        self.availableModels = modelIds
                    }
                }
            } else {
                self.isServerOnline = false
                self.serverLatencyMs = nil
            }
        } catch {
            self.isServerOnline = false
            self.serverLatencyMs = nil
            self.lastSyncError = error.localizedDescription
        }
    }
}
