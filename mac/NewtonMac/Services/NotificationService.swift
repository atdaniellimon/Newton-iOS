//
//  NotificationService.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Sends system notifications when Newton finishes responding and the window/app is unfocused.
//

import Foundation
import AppKit
import UserNotifications

public final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }
    
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    public func sendCompletionNotification(title: String = "Newton Singularity", body: String) {
        // Send notification if application is in background or inactive
        DispatchQueue.main.async {
            guard !NSApplication.shared.isActive else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body.isEmpty ? "Respuesta completada." : String(body.prefix(120))
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
