//
//  AuthManager.swift
//  Newton
//
//  Manages user authentication against auth.newton.daniellimon.uk
//  Stores the ntwn-... API key securely in Keychain.
//

import Foundation
import Security
import Combine

public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    // auth.newton.daniellimon.uk → localhost:6742 in production
    private let authBaseURL = "https://auth.newton.daniellimon.uk"

    private let keychainService = "com.newton.ai.auth"
    private let keychainKeyAccount = "nwtn_key"
    private let keychainUserAccount = "nwtn_username"

    @Published public var isLoggedIn: Bool = false
    @Published public var username: String = ""
    @Published public var creditsTotal: Int = 0
    @Published public var creditsUsed: Int = 0
    @Published public var trialEndsAt: Date? = nil
    @Published public var isLoading: Bool = false
    @Published public var lastError: String? = nil

    // Quota data from /auth/me
    @Published public var req5hUsed: Int = 0
    @Published public var req5hLimit: Int = 150
    @Published public var req5hResetAt: Date? = nil
    @Published public var msgsWeekUsed: Int = 0
    @Published public var msgsWeekLimit: Int = 1200
    @Published public var msgsWeekResetAt: Date? = nil
    @Published public var tokensWeekUsed: Int = 0
    @Published public var tokensWeekLimit: Int = 6_000_000
    @Published public var tokensWeekResetAt: Date? = nil

    private init() {
        // Restore session from Keychain on launch
        if let key = keychainGet(account: keychainKeyAccount), key.hasPrefix("ntwn-"),
           let user = keychainGet(account: keychainUserAccount) {
            self.isLoggedIn = true
            self.username = user
        }
    }

    // ── Public API ──────────────────────────────────────────────

    public var nwtnKey: String {
        keychainGet(account: keychainKeyAccount) ?? ""
    }

    public func register(username: String, password: String) async -> Bool {
        await performAuth(
            endpoint: "/auth/register",
            body: ["username": username, "password": password, "trial_days": 30]
        )
    }

    public func login(username: String, password: String) async -> Bool {
        await performAuth(
            endpoint: "/auth/login",
            body: ["username": username, "password": password]
        )
    }

    public func logout() {
        keychainDelete(account: keychainKeyAccount)
        keychainDelete(account: keychainUserAccount)
        DispatchQueue.main.async {
            self.isLoggedIn = false
            self.username = ""
            self.creditsTotal = 0
            self.creditsUsed = 0
            self.trialEndsAt = nil
        }
    }

    // ── User info / quotas ────────────────────────────────

    /// Fetches fresh quota + account data from GET /auth/me.
    @MainActor
    public func refreshUserInfo() async {
        let key = nwtnKey
        guard !key.isEmpty else { return }

        guard let url = URL(string: authBaseURL + "/auth/me") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            guard let http, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            if let u = json["username"] as? String, !u.isEmpty {
                self.username = u
                keychainSet(account: keychainUserAccount, value: u)
            }
            self.creditsTotal = json["credits_total"] as? Int ?? self.creditsTotal
            self.creditsUsed  = json["credits_used"] as? Int ?? self.creditsUsed
            if let ts = json["trial_ends_at"] as? TimeInterval {
                self.trialEndsAt = Date(timeIntervalSince1970: ts)
            }

            if let q = json["quotas"] as? [String: Any] {
                if let r = q["req_5h"] as? [String: Any] {
                    self.req5hUsed  = r["used"] as? Int ?? self.req5hUsed
                    self.req5hLimit = r["limit"] as? Int ?? self.req5hLimit
                    self.req5hResetAt = resetDate(r)
                }
                if let m = q["msgs_week"] as? [String: Any] {
                    self.msgsWeekUsed  = m["used"] as? Int ?? self.msgsWeekUsed
                    self.msgsWeekLimit = m["limit"] as? Int ?? self.msgsWeekLimit
                    self.msgsWeekResetAt = resetDate(m)
                }
                if let t = q["tokens_week"] as? [String: Any] {
                    self.tokensWeekUsed  = t["used"] as? Int ?? self.tokensWeekUsed
                    self.tokensWeekLimit = t["limit"] as? Int ?? self.tokensWeekLimit
                    self.tokensWeekResetAt = resetDate(t)
                }
            }
        } catch {
            // Quietly ignore — UI keeps last known values.
        }
    }

    private func resetDate(_ dict: [String: Any]) -> Date? {
        if let ts = dict["reset_at"] as? TimeInterval {
            return Date(timeIntervalSince1970: ts)
        }
        return nil
    }

    // ── Private helpers ──────────────────────────────────────────

    @MainActor
    private func performAuth(endpoint: String, body: [String: Any]) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard let url = URL(string: authBaseURL + endpoint) else {
            lastError = "Invalid server URL"
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

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            if let http, http.statusCode == 200 || http.statusCode == 201,
               let key = json["nwtn_key"] as? String, key.hasPrefix("ntwn-"),
               let user = json["username"] as? String {

                // Save to Keychain
                keychainSet(account: keychainKeyAccount, value: key)
                keychainSet(account: keychainUserAccount, value: user)

                self.isLoggedIn = true
                self.username = user
                self.creditsTotal = json["credits"] as? Int ?? json["credits_total"] as? Int ?? 0
                self.creditsUsed = json["credits_used"] as? Int ?? 0
                if let ts = json["trial_ends_at"] as? TimeInterval {
                    self.trialEndsAt = Date(timeIntervalSince1970: ts)
                }

                // Fetch fresh quota data in the background
                Task { await self.refreshUserInfo() }
                return true
            } else {
                // Extract error message
                if let errObj = json["error"] as? [String: Any],
                   let msg = errObj["message"] as? String {
                    lastError = msg
                } else {
                    lastError = "Server error (\(http?.statusCode ?? 0))"
                }
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // ── Keychain ─────────────────────────────────────────────────

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
