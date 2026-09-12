//
//  AuthManager.swift
//  Newton
//
//  Manages user authentication against api.newton.daniellimon.uk
//  Stores the ntwn-... API key securely in Keychain.
//

import Foundation
import Security
import Combine

// MARK: - Subscription Tier Models (API v2.2.0)

public struct SubscriptionTierInfo: Codable, Equatable {
    public var id: String
    public var name: String
    public var badge: String
    public var priceMXN: Int
    public var rpmLimit: Int
    public var dailyImagesUsed: Int
    public var dailyImagesLimit: String // e.g. "20", "100", "unlimited"
    public var allowedModels: [String]
    public var features: [String]
    public var expiresAt: Date?
    
    public static let base = SubscriptionTierInfo(
        id: "base",
        name: "Newton Base",
        badge: "Base",
        priceMXN: 250,
        rpmLimit: 60,
        dailyImagesUsed: 0,
        dailyImagesLimit: "20",
        allowedModels: ["Singularity"],
        features: [
            "Access to Newton Singularity",
            "10,000,000 monthly tokens",
            "60 RPM rate limit",
            "20 daily image generations",
            "200 requests / 5-hour window",
            "1,500 weekly messages"
        ],
        expiresAt: nil
    )
    
    public static let pro = SubscriptionTierInfo(
        id: "pro",
        name: "Newton Pro",
        badge: "Pro",
        priceMXN: 750,
        rpmLimit: 180,
        dailyImagesUsed: 0,
        dailyImagesLimit: "100",
        allowedModels: ["Singularity", "Singularity-Matrix"],
        features: [
            "Access to Singularity and Singularity-Matrix",
            "50,000,000 monthly tokens",
            "180 RPM rate limit",
            "100 daily image generations",
            "600 requests / 5-hour window",
            "7,500 weekly messages"
        ],
        expiresAt: nil
    )
    
    public static let matrix = SubscriptionTierInfo(
        id: "matrix",
        name: "Newton Matrix",
        badge: "Matrix",
        priceMXN: 3000,
        rpmLimit: 600,
        dailyImagesUsed: 0,
        dailyImagesLimit: "unlimited",
        allowedModels: ["*"],
        features: [
            "Unlimited access to all models (Singularity + Singularity-Matrix)",
            "Ultra performance: 600 RPM throughput",
            "250,000,000 monthly tokens (25x Base / 5x Pro)",
            "Unlimited daily image generations",
            "Highest server priority and zero queue",
            "Early access to Orbits and experimental tools"
        ],
        expiresAt: nil
    )

    public var localizedFeatures: [String] {
        if LocalizationManager.shared.isSpanish {
            switch id.lowercased() {
            case "pro":
                return [
                    "Acceso a Singularity y Singularity-Matrix",
                    "50,000,000 tokens mensuales",
                    "Límite de velocidad de 180 RPM",
                    "100 generaciones de imágenes al día",
                    "600 solicitudes / ventana de 5 horas",
                    "7,500 mensajes semanales"
                ]
            case "matrix":
                return [
                    "Acceso ilimitado a todos los modelos (Singularity + Singularity-Matrix)",
                    "Ultra rendimiento: 600 RPM de tasa de procesamiento",
                    "250,000,000 tokens mensuales (25x Base / 5x Pro)",
                    "Generación ilimitada de imágenes diarias",
                    "Máxima prioridad en servidor y cola cero",
                    "Acceso anticipado a Orbits y herramientas experimentales"
                ]
            default:
                return [
                    "Acceso a Newton Singularity",
                    "10,000,000 tokens mensuales",
                    "Límite de velocidad de 60 RPM",
                    "20 generaciones de imágenes al día",
                    "200 solicitudes / ventana de 5 horas",
                    "1,500 mensajes semanales"
                ]
            }
        }
        return features
    }

    public func canUseModel(_ modelId: String) -> Bool {
        if allowedModels.contains("*") { return true }
        let target = modelId.lowercased()
        return allowedModels.contains { allowed in
            let a = allowed.lowercased()
            return a == target || target.contains(a) || a.contains(target)
        }
    }
}

public struct QuotaWindow: Codable, Equatable {
    public var used: Int
    public var limit: Int
    public var resetAt: Date?
    
    public var percent: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, max(0.0, Double(used) / Double(limit)))
    }
}

public struct UsageAuditRecord: Identifiable, Codable {
    public var id: String { "\(timestamp)-\(endpoint)-\(tokens)" }
    public var timestamp: TimeInterval
    public var endpoint: String
    public var tokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var costTokens: Int
    public var status: Int
    
    public var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }
}

public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    public static let apiBaseURL = "https://api.newton.daniellimon.uk"

    private let keychainService = "com.newton.ai.auth"
    private let keychainKeyAccount = "nwtn_key"
    private let keychainUserAccount = "nwtn_username"

    @Published public var isLoggedIn: Bool = false
    @Published public var username: String = ""
    @Published public var email: String = ""
    @Published public var emailVerified: Bool = true
    
    // Tier & Subscription
    @Published public var tier: SubscriptionTierInfo = .base
    @Published public var creditsRemaining: Int = 10_000_000
    @Published public var creditsTotal: Int = 10_000_000
    @Published public var creditsUsed: Int = 0
    @Published public var trialEndsAt: Date? = nil
    @Published public var rpmLimit: Int = 60
    
    // Rolling Quotas
    @Published public var quotaReq5h: QuotaWindow = QuotaWindow(used: 0, limit: 200, resetAt: nil)
    @Published public var quotaMsgsWeek: QuotaWindow = QuotaWindow(used: 0, limit: 1500, resetAt: nil)
    @Published public var quotaTokensWeek: QuotaWindow = QuotaWindow(used: 0, limit: 10_000_000, resetAt: nil)

    // Legacy backwards-compatible aliases for existing views
    public var req5hUsed: Int { get { quotaReq5h.used } set { quotaReq5h.used = newValue } }
    public var req5hLimit: Int { get { quotaReq5h.limit } set { quotaReq5h.limit = newValue } }
    public var req5hResetAt: Date? { get { quotaReq5h.resetAt } set { quotaReq5h.resetAt = newValue } }
    public var msgsWeekUsed: Int { get { quotaMsgsWeek.used } set { quotaMsgsWeek.used = newValue } }
    public var msgsWeekLimit: Int { get { quotaMsgsWeek.limit } set { quotaMsgsWeek.limit = newValue } }
    public var msgsWeekResetAt: Date? { get { quotaMsgsWeek.resetAt } set { quotaMsgsWeek.resetAt = newValue } }
    public var tokensWeekUsed: Int { get { quotaTokensWeek.used } set { quotaTokensWeek.used = newValue } }
    public var tokensWeekLimit: Int { get { quotaTokensWeek.limit } set { quotaTokensWeek.limit = newValue } }
    public var tokensWeekResetAt: Date? { get { quotaTokensWeek.resetAt } set { quotaTokensWeek.resetAt = newValue } }

    // Usage History Records
    @Published public var recentUsageRecords: [UsageAuditRecord] = []
    
    // UI state
    @Published public var isLoading: Bool = false
    @Published public var lastError: String? = nil
    @Published public var isRotatingKey: Bool = false
    @Published public var lastKeyRotationMessage: String? = nil

    private init() {
        if let key = keychainGet(account: keychainKeyAccount), key.hasPrefix("ntwn-"),
           let user = keychainGet(account: keychainUserAccount) {
            self.isLoggedIn = true
            self.username = user
        }
    }

    public var nwtnKey: String {
        keychainGet(account: keychainKeyAccount) ?? ""
    }

    // MARK: - Authentication Methods

    public func register(username: String, email: String? = nil, password: String, tier: String = "base") async -> Bool {
        var body: [String: Any] = [
            "username": username,
            "password": password,
            "tier": tier
        ]
        if let email, !email.isEmpty {
            body["email"] = email
        }
        return await performAuth(endpoint: "/auth/register", body: body)
    }

    public func login(username: String, password: String) async -> Bool {
        await performAuth(
            endpoint: "/auth/login",
            body: ["username": username, "password": password]
        )
    }

    // MARK: - Quota & Profile Synchronization (GET /auth/me)

    @MainActor
    public func refreshUserInfo() async {
        let key = nwtnKey
        guard !key.isEmpty else { return }

        guard let url = URL(string: Self.apiBaseURL + "/auth/me") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            if let u = json["username"] as? String, !u.isEmpty {
                self.username = u
                keychainSet(account: keychainUserAccount, value: u)
            }
            if let e = json["email"] as? String {
                self.email = e
            }
            if let ev = json["email_verified"] as? Bool {
                self.emailVerified = ev
            }
            if let rpm = json["rpm_limit"] as? Int {
                self.rpmLimit = rpm
            }

            // Credits
            if let creditsObj = json["credits"] as? [String: Any] {
                self.creditsTotal = creditsObj["total"] as? Int ?? self.creditsTotal
                self.creditsUsed = creditsObj["used"] as? Int ?? self.creditsUsed
                self.creditsRemaining = creditsObj["remaining"] as? Int ?? (self.creditsTotal - self.creditsUsed)
            } else if let credLeft = json["credits_left"] as? Int {
                self.creditsRemaining = credLeft
            }

            // Tier
            if let tDict = json["tier"] as? [String: Any] {
                let tierId = (tDict["id"] as? String ?? "base").lowercased()
                var parsedTier = (tierId == "matrix" ? SubscriptionTierInfo.matrix : (tierId == "pro" ? SubscriptionTierInfo.pro : SubscriptionTierInfo.base))
                if let name = tDict["name"] as? String { parsedTier.name = name }
                if let badge = tDict["badge"] as? String { parsedTier.badge = badge }
                if let price = tDict["price_mxn"] as? Int { parsedTier.priceMXN = price }
                if let rpm = tDict["rpm_limit"] as? Int { parsedTier.rpmLimit = rpm }
                if let allowed = tDict["allowed_models"] as? [String] { parsedTier.allowedModels = allowed }
                if let features = tDict["features"] as? [String] { parsedTier.features = features }
                if let exp = tDict["expires_at"] as? TimeInterval {
                    parsedTier.expiresAt = Date(timeIntervalSince1970: exp)
                    self.trialEndsAt = parsedTier.expiresAt
                }
                if let dailyImages = tDict["daily_images"] as? [String: Any] {
                    parsedTier.dailyImagesUsed = dailyImages["used"] as? Int ?? 0
                    if let rem = dailyImages["remaining"] as? String {
                        parsedTier.dailyImagesLimit = rem
                    } else if let lim = dailyImages["limit"] as? Int {
                        parsedTier.dailyImagesLimit = "\(lim)"
                    }
                }
                self.tier = parsedTier
            }

            // Quotas
            if let q = json["quotas"] as? [String: Any] {
                if let r = q["req_5h"] as? [String: Any] {
                    self.quotaReq5h = QuotaWindow(
                        used: r["used"] as? Int ?? self.quotaReq5h.used,
                        limit: r["limit"] as? Int ?? self.quotaReq5h.limit,
                        resetAt: resetDate(r)
                    )
                }
                if let m = q["msgs_week"] as? [String: Any] {
                    self.quotaMsgsWeek = QuotaWindow(
                        used: m["used"] as? Int ?? self.quotaMsgsWeek.used,
                        limit: m["limit"] as? Int ?? self.quotaMsgsWeek.limit,
                        resetAt: resetDate(m)
                    )
                }
                if let t = q["tokens_week"] as? [String: Any] {
                    self.quotaTokensWeek = QuotaWindow(
                        used: t["used"] as? Int ?? self.quotaTokensWeek.used,
                        limit: t["limit"] as? Int ?? self.quotaTokensWeek.limit,
                        resetAt: resetDate(t)
                    )
                }
            }
        } catch {
            // Keep last cached values
        }
    }

    // MARK: - Key Rotation (POST /auth/rotate-key)

    @MainActor
    public func rotateApiKey() async -> (success: Bool, message: String) {
        let key = nwtnKey
        guard !key.isEmpty else { return (false, "No API key found") }

        isRotatingKey = true
        defer { isRotatingKey = false }

        guard let url = URL(string: Self.apiBaseURL + "/auth/rotate-key") else {
            return (false, "Invalid URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newKey = json["api_key"] as? String, newKey.hasPrefix("ntwn-") else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "Failed to rotate key"
                return (false, msg)
            }

            keychainSet(account: keychainKeyAccount, value: newKey)
            let successMsg = json["message"] as? String ?? "API Key rotated successfully."
            self.lastKeyRotationMessage = successMsg
            Haptics.success()
            return (true, successMsg)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Usage History (GET /nwtn/usage/history)

    @MainActor
    public func fetchUsageHistory(days: Int = 7) async {
        let key = nwtnKey
        guard !key.isEmpty else { return }

        guard let url = URL(string: Self.apiBaseURL + "/nwtn/usage/history?days=\(days)&limit=30") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let records = json["records"] as? [[String: Any]] else {
                return
            }

            self.recentUsageRecords = records.compactMap { dict in
                guard let ts = dict["timestamp"] as? TimeInterval,
                      let ep = dict["endpoint"] as? String,
                      let tokens = dict["tokens"] as? Int else { return nil }

                return UsageAuditRecord(
                    timestamp: ts,
                    endpoint: ep,
                    tokens: tokens,
                    inputTokens: dict["input_tokens"] as? Int ?? 0,
                    outputTokens: dict["output_tokens"] as? Int ?? 0,
                    costTokens: dict["cost_tokens"] as? Int ?? tokens,
                    status: dict["status"] as? Int ?? 200
                )
            }
        } catch {
            // Keep last records
        }
    }

    // MARK: - Realtime Stream Credits Update

    @MainActor
    public func updateCreditsFromStream(_ newCreditsRemaining: Int) {
        self.creditsRemaining = newCreditsRemaining
    }

    @MainActor
    public func logout() {
        let key = nwtnKey
        if !key.isEmpty, let url = URL(string: Self.apiBaseURL + "/auth/logout") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req).resume()
        }

        // 1. Wipe Keychain Credentials
        keychainDelete(account: keychainKeyAccount)
        keychainDelete(account: keychainUserAccount)

        // 2. Wipe Local & iCloud Chats & Conversations
        StorageManager.shared.clearAllConversations()

        // 3. Wipe Long-Term Learned Memories
        MemoryManager.shared.clearAllMemories()

        // 4. Wipe Custom Workspaces
        WorkspaceManager.shared.clearAllWorkspaces()

        // 5. End Any Active Live Activity / Dynamic Island
        LiveActivityManager.shared.endCurrentActivity()

        // 6. Reset in-memory session and quota state
        self.isLoggedIn = false
        self.username = ""
        self.email = ""
        self.creditsTotal = 0
        self.creditsUsed = 0
        self.creditsRemaining = 0
        self.trialEndsAt = nil
        self.tier = .base
        self.quotaReq5h = QuotaWindow(used: 0, limit: 200, resetAt: nil)
        self.quotaMsgsWeek = QuotaWindow(used: 0, limit: 1500, resetAt: nil)
        self.quotaTokensWeek = QuotaWindow(used: 0, limit: 10_000_000, resetAt: nil)
        self.recentUsageRecords = []
        self.lastError = nil
    }

    // MARK: - Private Helpers

    private func resetDate(_ dict: [String: Any]) -> Date? {
        if let ts = dict["reset_at"] as? TimeInterval {
            return Date(timeIntervalSince1970: ts)
        }
        return nil
    }

    @MainActor
    private func performAuth(endpoint: String, body: [String: Any]) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard let url = URL(string: Self.apiBaseURL + endpoint) else {
            lastError = L10n.tr("Invalid URL", es: "URL inválida")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse

            let json: [String: Any]
            do {
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    lastError = L10n.tr("Invalid server response", es: "Respuesta inválida del servidor")
                    return false
                }
                json = parsed
            } catch {
                lastError = L10n.tr("The server returned an invalid response", es: "El servidor devolvió una respuesta inválida")
                return false
            }

            if let errObj = json["error"] as? [String: Any],
               let msg = errObj["message"] as? String {
                lastError = msg
                return false
            }

            if let detail = json["detail"] as? String {
                lastError = detail
                return false
            }

            if let http, (http.statusCode == 200 || http.statusCode == 201),
               let key = (json["api_key"] as? String ?? json["nwtn_key"] as? String),
               key.hasPrefix("ntwn-"),
               let user = json["username"] as? String {

                keychainSet(account: keychainKeyAccount, value: key)
                keychainSet(account: keychainUserAccount, value: user)

                self.isLoggedIn = true
                self.username = user
                if let email = json["email"] as? String {
                    self.email = email
                }
                if let creds = json["credits_left"] as? Int {
                    self.creditsRemaining = creds
                }
                if let tDict = json["tier"] as? [String: Any] {
                    let tid = (tDict["id"] as? String ?? "base").lowercased()
                    self.tier = tid == "matrix" ? .matrix : (tid == "pro" ? .pro : .base)
                }

                Task { await self.refreshUserInfo() }
                return true
            } else {
                lastError = L10n.tr("Server error", es: "Error del servidor") + " (\(http?.statusCode ?? 0))"
                return false
            }
        } catch {
            lastError = L10n.tr("Connection error", es: "Error de conexión") + ": \(error.localizedDescription)"
            return false
        }
    }

    private func keychainSet(account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        keychainDelete(account: account)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      keychainService,
            kSecAttrAccount as String:      account,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainGet(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  account,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func keychainDelete(account: String) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
