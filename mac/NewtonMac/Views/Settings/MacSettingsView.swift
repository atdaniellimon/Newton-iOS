//
//  MacSettingsView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Clean, rich preferences screen.
//

import SwiftUI
import AppKit

public struct MacSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var storage = StorageManager.shared
    @State private var showingClearCacheAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        TabView {
            // General Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Appearance
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Appearance & Typography")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        Picker("App Theme:", selection: $settings.appThemeRaw) {
                            ForEach(AppThemeMode.allCases, id: \.rawValue) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        
                        Divider()
                            .padding(.vertical, 2)
                        
                        Toggle("Show Code Block Line Numbers", isOn: $settings.codeLineNumbers)
                        Toggle("Render LaTeX Math Equations", isOn: $settings.latexRendering)
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
                    
                    // Interaction
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Chat & Streaming")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        Toggle("Auto-Scroll To Bottom During Streaming", isOn: $settings.autoScrollOnStream)
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
                    
                    // Storage & Data
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Storage & Privacy")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        HStack {
                            Text("Total Conversations:")
                                .foregroundColor(NewtonTheme.textSecondary)
                            Spacer()
                            Text("\(storage.conversations.count)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        
                        HStack {
                            Text("Total Stored Messages:")
                                .foregroundColor(NewtonTheme.textSecondary)
                            Spacer()
                            let count = storage.conversations.reduce(0) { $0 + $1.messages.count }
                            Text("\(count)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        
                        Divider()
                            .padding(.vertical, 2)
                        
                        Button("Clear Temporary Cache") {
                            URLCache.shared.removeAllCachedResponses()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
                }
                .padding(20)
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            // About Tab
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(NewtonTheme.sand.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                VStack(spacing: 4) {
                    Text("Newton Singularity")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                    
                    Text("macOS Universal Edition • Monterey 12.0+")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textSecondary)
                    
                    Text("Zero-Knowledge Local Storage")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.forestGreen)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 480, height: 420)
    }
}
