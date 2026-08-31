//
//  NewtonApp.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

@main
struct NewtonApp: App {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var storage = StorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(colorScheme)
                .environmentObject(settings)
                .environmentObject(storage)
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch settings.appTheme {
        case .dark:
            return .dark
        case .light:
            return .light
        case .system:
            return nil
        }
    }
}
