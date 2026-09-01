//
//  MacSettingsView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var apiKeyInput: String = ""
    
    public init() {}
    
    public var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Newton Singularity Cloud Engine Status
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(NewtonTheme.sand.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "bolt.horizontal.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Newton Singularity Engine")
                                    .font(.system(size: 13.5, weight: .bold, design: .serif))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                
                                Text("Connected to Cloud Endpoint")
                                    .font(.system(size: 11))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text("LIVE")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundColor(NewtonTheme.forestGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(NewtonTheme.forestGreen.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        HStack {
                            Text("Endpoint:")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(NewtonTheme.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(SettingsManager.hardcodedEndpoint)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NewtonTheme.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
                    
                    // Authentication
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Authorization (Optional)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        HStack {
                            Text("API Key:")
                                .frame(width: 80, alignment: .leading)
                            SecureField("Optional Bearer Token...", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button("Save Authorization") {
                            settings.setApiKey(apiKeyInput, for: settings.currentProvider)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
                    
                    // Theme
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Appearance")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        Picker("App Theme:", selection: $settings.appThemeRaw) {
                            ForEach(AppThemeMode.allCases, id: \.rawValue) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.radioGroup)
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 480, height: 380)
        .onAppear {
            apiKeyInput = settings.currentApiKey
        }
    }
}
