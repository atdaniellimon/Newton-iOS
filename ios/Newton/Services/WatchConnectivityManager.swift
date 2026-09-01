//
//  WatchConnectivityManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Syncs conversations and supports queries from Apple Watch companion.
//

import Foundation
import WatchConnectivity
import SwiftUI

public final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchConnectivityManager()
    
    @Published public var isWatchAppInstalled: Bool = false
    @Published public var isReachable: Bool = false
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    public func syncConversationsToWatch() {
        guard WCSession.isSupported() && WCSession.default.activationState == .activated else { return }
        
        let conversations = StorageManager.shared.conversations
        let summaryList = conversations.prefix(10).map { conv in
            [
                "id": conv.id,
                "title": conv.title,
                "lastMessage": conv.messages.last?.content ?? "",
                "updatedAt": conv.updatedAt.timeIntervalSince1970
            ] as [String: Any]
        }
        
        try? WCSession.default.updateApplicationContext(["recentConversations": summaryList])
    }
    
    // WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let query = message["query"] as? String {
            // Process quick query from Apple Watch
            Task {
                var responseText = ""
                let settings = SettingsManager.shared
                let dummyMsg = Message(role: .user, content: query)
                
                do {
                    let stream = LLMService.shared.streamCompletion(
                        messages: [dummyMsg],
                        provider: settings.currentProvider,
                        modelId: settings.currentModelId,
                        baseUrl: settings.effectiveBaseUrl(for: settings.currentProvider),
                        apiKey: settings.currentApiKey
                    )
                    for try await token in stream {
                        responseText += token
                    }
                    replyHandler(["response": responseText])
                } catch {
                    replyHandler(["response": "Error: \(error.localizedDescription)"])
                }
            }
        }
    }
}
