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
                .preferredColorScheme(.dark)
                .environmentObject(settings)
                .environmentObject(storage)
        }
    }
}
