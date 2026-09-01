//
//  SettingsView.swift
//  Newton
//
//  Created for Newton iOS.
//  Clean, rich preferences screen.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var syncService = iCloudSyncService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingClearCacheAlert: Bool = false
    @State private var cacheClearedMessage: String? = nil
    @State private var exportUrl: URL? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg
                    .ignoresSafeArea()
                
                Form {
                    // Appearance Section
                    Section(header: Text("APPEARANCE").foregroundColor(NewtonTheme.textSecondary)) {
                        Picker("Theme", selection: $settings.appTheme) {
                            ForEach(AppThemeMode.allCases) { mode in
                                Label(mode.displayName, systemImage: mode.iconName)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                        
                        Toggle(isOn: $settings.codeLineNumbers) {
                            HStack {
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(NewtonTheme.sand)
                                Text("Code Block Line Numbers")
                            }
                        }
                        
                        Toggle(isOn: $settings.latexRendering) {
                            HStack {
                                Image(systemName: "function")
                                    .foregroundColor(NewtonTheme.sand)
                                Text("Render LaTeX Math")
                            }
                        }
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Chat & Interaction Section
                    Section(header: Text("INTERACTION").foregroundColor(NewtonTheme.textSecondary)) {
                        Toggle(isOn: $settings.hapticFeedbackEnabled) {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundColor(NewtonTheme.sand)
                                Text("Haptic Feedback")
                            }
                        }
                        
                        Toggle(isOn: $settings.autoScrollOnStream) {
                            HStack {
                                Image(systemName: "arrow.down.to.line")
                                    .foregroundColor(NewtonTheme.sand)
                                Text("Auto-Scroll During Generation")
                            }
                        }
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // iCloud Synchronization
                    Section(header: Text("ICLOUD SYNCHRONIZATION").foregroundColor(NewtonTheme.textSecondary)) {
                        HStack {
                            Label("iCloud Status", systemImage: "icloud.fill")
                                .foregroundColor(NewtonTheme.textPrimary)
                            Spacer()
                            HStack(spacing: 6) {
                                if syncService.isSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Circle()
                                        .fill(NewtonTheme.forestGreen)
                                        .frame(width: 8, height: 8)
                                }
                                Text(syncService.syncStatusText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                        }
                        
                        Button {
                            syncService.triggerManualSync()
                            Haptics.medium()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync with iCloud Now")
                            }
                            .foregroundColor(NewtonTheme.sand)
                        }
                        .disabled(syncService.isSyncing)
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Storage & Data Statistics
                    Section(header: Text("STORAGE & DATA").foregroundColor(NewtonTheme.textSecondary)) {
                        HStack {
                            Text("Total Conversations")
                                .foregroundColor(NewtonTheme.textPrimary)
                            Spacer()
                            Text("\(storage.conversations.count)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        
                        HStack {
                            Text("Total Messages Stored")
                                .foregroundColor(NewtonTheme.textPrimary)
                            Spacer()
                            let count = storage.conversations.reduce(0) { $0 + $1.messages.count }
                            Text("\(count)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        
                        Button(role: .destructive) {
                            showingClearCacheAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Temporary Cache")
                            }
                            .foregroundColor(NewtonTheme.coralRed)
                        }
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Privacy & Security
                    Section(header: Text("PRIVACY & ARCHITECTURE").foregroundColor(NewtonTheme.textSecondary)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(NewtonTheme.forestGreen)
                                Text("Zero-Knowledge Local Storage")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(NewtonTheme.textPrimary)
                            }
                            
                            Text("All conversations, documents, and generated images remain securely on your device. Nothing is shared with third-party tracking or advertising services.")
                                .font(.system(size: 11.5))
                                .foregroundColor(NewtonTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // About App
                    Section(header: Text("ABOUT").foregroundColor(NewtonTheme.textSecondary)) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("3.9 (Universal)")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }
                        
                        HStack {
                            Text("Engine")
                            Spacer()
                            Text("Newton Singularity Core")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundColor(NewtonTheme.sand)
                        }
                    }
                    .listRowBackground(NewtonTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(NewtonTheme.sand)
                }
            }
            .alert("Clear Temporary Cache?", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    URLCache.shared.removeAllCachedResponses()
                    Haptics.medium()
                }
            } message: {
                Text("This will purge temporary image and PDF caches without deleting your conversations.")
            }
        }
    }
}
