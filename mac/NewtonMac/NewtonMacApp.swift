//
//  NewtonMacApp.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Modern header-less window with unified traffic light controls.
//

import SwiftUI
import AppKit

@main
struct NewtonMacApp: App {
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    
    init() {
        _ = NotificationService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainMacSplitView()
                .frame(minWidth: 840, minHeight: 540)
                .background(WindowAccessor())
                .preferredColorScheme(settings.appTheme.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
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

public struct WindowAccessor: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.backgroundColor = .clear
            }
        }
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {}
}
