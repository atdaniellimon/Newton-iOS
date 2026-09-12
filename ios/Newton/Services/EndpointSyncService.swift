//
//  EndpointSyncService.swift
//  Newton
//
//  Health-checks the NWTN endpoint (/nwtn/models) with the user's key.
//  Reads the active endpoint from config.json on GitHub (unchanged).
//

import Foundation
import Combine

public final class EndpointSyncService: ObservableObject {
    public static let shared = EndpointSyncService()

    private let remoteConfigUrl    = "https://raw.githubusercontent.com/atdaniellimon/Newton-iOS/main/config.json"
    private let remoteEndpointTxt  = "https://raw.githubusercontent.com/atdaniellimon/Newton-iOS/main/endpoint.txt"

    @Published public var activeEndpoint: String  = SettingsManager.nwtnBaseURL
    @Published public var isServerOnline: Bool     = false
    @Published public var serverLatencyMs: Int?    = nil
    @Published public var availableModels: [String] = ["Singularity", "Singularity-Matrix"]
    @Published public var models: [AIModel]        = DefaultModelCatalog.models()
    @Published public var isSyncing: Bool           = false
    @Published public var lastSyncDate: Date?       = nil
    @Published public var lastSyncError: String?    = nil

    private init() {
        Task { await syncAndValidateEndpoint() }
    }

    @MainActor
    public func syncAndValidateEndpoint() async {
        isSyncing = true
        lastSyncError = nil

        var resolvedUrl: String? = nil

        // 1. Try config.json
        if let configUrl = URL(string: "\(remoteConfigUrl)?t=\(Int(Date().timeIntervalSince1970))") {
            var req = URLRequest(url: configUrl)
            req.timeoutInterval = 3
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ep = json["endpoint"] as? String, !ep.isEmpty {
                resolvedUrl = ep.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 2. Fallback to endpoint.txt
        if resolvedUrl == nil,
           let txtUrl = URL(string: "\(remoteEndpointTxt)?t=\(Int(Date().timeIntervalSince1970))") {
            var req = URLRequest(url: txtUrl)
            req.timeoutInterval = 3
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let str = String(data: data, encoding: .utf8) {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { resolvedUrl = trimmed }
            }
        }

        // Always use the NWTN base; remote config might override the tunnel URL
        let target = resolvedUrl ?? SettingsManager.nwtnBaseURL
        self.activeEndpoint = target
        SettingsManager.shared.customBaseUrl = target

        // 3. Health-check /nwtn/models
        await checkServerHealth(endpoint: target)

        self.isSyncing   = false
        self.lastSyncDate = Date()
    }

    @MainActor
    public func checkServerHealth(endpoint: String) async {
        // Build URL: endpoint already ends with /nwtn, so append /models
        let base = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let modelsUrl = base.hasSuffix("/models") ? base : "\(base)/models"

        guard let url = URL(string: modelsUrl) else {
            self.isServerOnline = false; return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 5

        // Attach user key if available
        let key = AuthManager.shared.nwtnKey
        if !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let latency = Int(Date().timeIntervalSince(start) * 1000)

            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.isServerOnline  = true
                self.serverLatencyMs = latency

                self.parseModelsFromData(data)
            } else {
                self.isServerOnline  = false
                self.serverLatencyMs = nil
            }
        } catch {
            self.isServerOnline  = false
            self.serverLatencyMs = nil
            self.lastSyncError   = error.localizedDescription
        }
    }

    @MainActor
    public func fetchAvailableModels() async {
        let endpoint = SettingsManager.nwtnBaseURL + "/models"
        guard let url = URL(string: endpoint) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 10
        let key = AuthManager.shared.nwtnKey
        if !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            self.parseModelsFromData(data)
        }
    }

    @MainActor
    private func parseModelsFromData(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["data"] as? [[String: Any]] else {
            return
        }

        let parsedModels: [AIModel] = arr.compactMap { dict -> AIModel? in
            guard let id = dict["id"] as? String else { return nil }
            let ownedBy = dict["owned_by"] as? String ?? "Newton Labs"
            let capabilities = dict["capabilities"] as? [String] ?? ["chat"]
            let description = dict["description"] as? String ?? ""

            let iconName: String
            if capabilities.contains("code") || id.lowercased().contains("matrix") {
                iconName = "chevron.left.forwardslash.chevron.right"
            } else {
                iconName = "atom"
            }

            let displayName: String
            if id == "Singularity" {
                displayName = "Newton Singularity"
            } else if id == "Singularity-Matrix" {
                displayName = "Singularity Matrix"
            } else {
                displayName = id
            }

            return AIModel(
                id: id,
                name: displayName,
                provider: .newton,
                description: description,
                iconName: iconName,
                capabilities: capabilities,
                ownedBy: ownedBy
            )
        }

        if !parsedModels.isEmpty {
            self.models = parsedModels
            self.availableModels = parsedModels.map { $0.id }
            SettingsManager.shared.availableModels = parsedModels
        }
    }
}
