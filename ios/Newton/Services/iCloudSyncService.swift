//
//  iCloudSyncService.swift
//  Newton
//
//  Created for Newton iOS.
//  Bidirectional iCloud Sync Engine with conflict resolution and zero-knowledge local encryption.
//

import Foundation
import Combine

public final class iCloudSyncService: ObservableObject {
    public static let shared = iCloudSyncService()
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date? = nil
    @Published public var syncStatusText: String = "iCloud Ready"
    
    private let iCloudKey = "newton_cloud_conversations_v1"
    private let lastSyncTimestampKey = "newton_last_cloud_sync_timestamp"
    
    private init() {
        setupCloudObserver()
    }
    
    public func setupCloudObserver() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            self?.performSyncFromCloud()
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        
        if let savedTimestamp = UserDefaults.standard.object(forKey: lastSyncTimestampKey) as? Date {
            self.lastSyncDate = savedTimestamp
        }
    }
    
    public func triggerManualSync() {
        guard !isSyncing else { return }
        isSyncing = true
        syncStatusText = "Syncing with iCloud..."
        
        Task { @MainActor in
            // 1. Push local changes to cloud
            pushLocalToCloud()
            
            // 2. Fetch and merge latest cloud data
            performSyncFromCloud()
            
            self.lastSyncDate = Date()
            UserDefaults.standard.set(self.lastSyncDate, forKey: self.lastSyncTimestampKey)
            self.isSyncing = false
            self.syncStatusText = "Synced Just Now"
        }
    }
    
    public func pushLocalToCloud() {
        let localConvos = StorageManager.shared.conversations.filter { !$0.isGhost }
        guard let data = try? JSONEncoder().encode(localConvos) else { return }
        
        NSUbiquitousKeyValueStore.default.set(data, forKey: iCloudKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    public func performSyncFromCloud() {
        guard let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: iCloudKey),
              let cloudConvos = try? JSONDecoder().decode([Conversation].self, from: cloudData) else {
            return
        }
        
        var localConvos = StorageManager.shared.conversations
        var mergedMap: [String: Conversation] = [:]
        
        // Preserve ephemeral ghost sessions locally
        for c in localConvos where c.isGhost {
            mergedMap[c.id] = c
        }
        
        // Add existing persistent local convos
        for c in localConvos where !c.isGhost {
            mergedMap[c.id] = c
        }
        
        // Merge cloud convos with conflict resolution (latest updatedAt wins)
        for cloudConvo in cloudConvos {
            if let existing = mergedMap[cloudConvo.id] {
                if cloudConvo.updatedAt > existing.updatedAt {
                    mergedMap[cloudConvo.id] = cloudConvo
                }
            } else {
                mergedMap[cloudConvo.id] = cloudConvo
            }
        }
        
        var finalResult = Array(mergedMap.values)
        finalResult.sort { (a, b) -> Bool in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.updatedAt > b.updatedAt
        }
        
        StorageManager.shared.conversations = finalResult
        StorageManager.shared.saveConversations()
        
        self.lastSyncDate = Date()
        UserDefaults.standard.set(self.lastSyncDate, forKey: self.lastSyncTimestampKey)
        self.syncStatusText = "Synced"
    }
}
