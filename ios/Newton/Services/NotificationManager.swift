//
//  NotificationManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Background Task Execution & Local Notification Engine.
//

import Foundation
import UserNotifications
import UIKit

public final class NotificationManager {
    public static let shared = NotificationManager()
    
    private init() {}
    
    /// Request notification authorization from user
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    /// Send a local notification when generation finishes in the background
    public func sendResponseReadyNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Newton • \(title)"
        content.body = body.isEmpty ? "Your response is ready." : String(body.prefix(160))
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error delivering local notification: \(error)")
            }
        }
    }
    
    /// Execute background task keeping network connection alive
    public func beginBackgroundTask(name: String, task: @escaping () async -> Void) {
        let bgTaskId = UIApplication.shared.beginBackgroundTask(withName: name) {
            // Expiration handler
        }
        
        Task {
            await task()
            await MainActor.run {
                if bgTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTaskId)
                }
            }
        }
    }
}
