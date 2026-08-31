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
    @AppStorage("newton_app_theme") private var appThemeRaw: String = AppThemeMode.dark.rawValue
    
    private var colorScheme: ColorScheme? {
        switch appThemeRaw {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
    
    init() {
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(colorScheme)
        }
    }
}
