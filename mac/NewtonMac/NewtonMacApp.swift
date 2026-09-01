//
//  NewtonMacApp.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

@main
struct NewtonMacApp: App {
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainMacSplitView()
                .frame(minWidth: 800, minHeight: 520)
                .preferredColorScheme(settings.appTheme == .light ? .light : (settings.appTheme == .dark ? .dark : nil))
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    _ = storage.createConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Newton") {
                Button("Clear All History") {
                    StorageManager.shared.clearAllConversations()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
        
        #if os(macOS)
        Settings {
            MacSettingsView()
        }
        #endif
    }
}
