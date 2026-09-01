//
//  MacSettingsView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Clean, modern preferences modal matching Apple HIG and Newton aesthetic.
//

import SwiftUI
import AppKit

public struct MacSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var syncService = iCloudSyncService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingClearCacheAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text("Settings")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(Color(NSColor.labelColor))
                }
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(NewtonTheme.sand)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)
            
            Divider()
            
            // Settings Content
            ScrollView {
                VStack(spacing: 16) {
                    // Appearance & Theme Card
                    settingsCard(title: "APPEARANCE & THEME", icon: "paintbrush.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Theme", selection: $settings.appThemeRaw) {
                                ForEach(AppThemeMode.allCases, id: \.rawValue) { mode in
                                    Label(mode.displayName, systemImage: mode.iconName)
                                        .tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 2)
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            Toggle("Show Code Block Line Numbers", isOn: $settings.codeLineNumbers)
                            Toggle("Render LaTeX Math Equations", isOn: $settings.latexRendering)
                        }
                    }
                    
                    // Interaction Card
                    settingsCard(title: "INTERACTION", icon: "bubble.left.and.bubble.right.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Auto-Scroll To Bottom During Streaming", isOn: $settings.autoScrollOnStream)
                        }
                    }
                    
                    // iCloud Synchronization Card
                    settingsCard(title: "ICLOUD SYNCHRONIZATION", icon: "icloud.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("iCloud Sync Status:")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                                
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    if syncService.isSyncing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Circle()
                                            .fill(NewtonTheme.forestGreen)
                                            .frame(width: 7, height: 7)
                                    }
                                    Text(syncService.syncStatusText)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                                }
                            }
                            
                            Button(action: {
                                syncService.triggerManualSync()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Sync with iCloud Now")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(NewtonTheme.sand)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(syncService.isSyncing)
                        }
                    }
                    
                    // Storage & Privacy Card
                    settingsCard(title: "STORAGE & PRIVACY", icon: "lock.shield.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Total Conversations:")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                                Spacer()
                                Text("\(storage.conversations.count)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            
                            HStack {
                                Text("Total Stored Messages:")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                                Spacer()
                                let count = storage.conversations.reduce(0) { $0 + $1.messages.count }
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            HStack {
                                Button(action: {
                                    URLCache.shared.removeAllCachedResponses()
                                    showingClearCacheAlert = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                        Text("Clear Temporary Cache")
                                    }
                                    .font(.system(size: 11.5))
                                    .foregroundColor(NewtonTheme.coralRed)
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                if showingClearCacheAlert {
                                    Text("Purged!")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(NewtonTheme.forestGreen)
                                }
                            }
                        }
                    }
                    
                    // About
                    VStack(spacing: 4) {
                        Text("Newton Singularity Core • macOS Universal")
                            .font(.system(size: 11))
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        Text("Zero-Knowledge Local Storage")
                            .font(.system(size: 10.5))
                            .foregroundColor(NewtonTheme.forestGreen.opacity(0.8))
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(settings.appTheme.colorScheme)
    }
    
    @ViewBuilder
    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.sand)
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
            
            content()
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.8)
        )
    }
}
