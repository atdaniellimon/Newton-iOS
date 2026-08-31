//
//  NewtonApp.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

@main
struct NewtonApp: App {
    @ObservedObject private var settings = SettingsManager.shared
    
    init() {
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(settings.appTheme.colorScheme)
        }
    }
}
