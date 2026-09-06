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
    @ObservedObject var memoryManager = MemoryManager.shared
    @ObservedObject var endpointSync = EndpointSyncService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingClearCacheAlert: Bool = false
    @State private var cacheClearedMessage: String? = nil
    @State private var exportUrl: URL? = nil
    @State private var newMemoryInput: String = ""
    @State private var showingWipeMemoriesAlert: Bool = false
    @State private var isSynthesizingMemory: Bool = false
    @State private var synthesisStatusText: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg
                .ignoresSafeArea()
                
                Form {
                    // Server & Cloud Tunnel Section
                    Section(header: Text("SERVER & CLOUD TUNNEL").foregroundColor(NewtonTheme.textSecondary)) {
                        HStack {
                            Label("Estado del Servidor", systemImage: "antenna.radiowaves.left.and.right")
                                .foregroundColor(NewtonTheme.textPrimary)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(endpointSync.isServerOnline ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                                    .frame(width: 8, height: 8)
                                Text(endpointSync.isServerOnline ? "Online" : "Offline")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(endpointSync.isServerOnline ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                                if let latency = endpointSync.serverLatencyMs {
                                    Text("(\(latency)ms)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(NewtonTheme.textSecondary)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Endpoint Activo:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(NewtonTheme.textSecondary)
                            Text(endpointSync.activeEndpoint)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NewtonTheme.sand)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 2)
                        
                        Button {
                            Haptics.medium()
                            Task {
                                await endpointSync.syncAndValidateEndpoint()
                                Haptics.success()
                            }
                        } label: {
                            HStack {
                                if endpointSync.isSyncing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text("Sincronizar desde GitHub (config.json)")
                            }
                            .foregroundColor(NewtonTheme.sand)
                        }
                        .disabled(endpointSync.isSyncing)
                    }
                    .listRowBackground(NewtonTheme.card)
                    
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
                    Section(header: Text("INTERACTION & VOICE").foregroundColor(NewtonTheme.textSecondary)) {
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
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label("Velocidad de Voz", systemImage: "waveform")
                                    .foregroundColor(NewtonTheme.textPrimary)
                                Spacer()
                                Text(String(format: "%.2fx", settings.speechRate * 2.0))
                                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            
                            Slider(value: $settings.speechRate, in: 0.35...0.75, step: 0.05)
                                .tint(NewtonTheme.sand)
                        }
                        .padding(.vertical, 2)
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
                    
                    // Persistent Long-Term Memory Section
                    Section(header: Text("MEMORIA PERSISTENTE (LONG-TERM MEMORY)").foregroundColor(NewtonTheme.textSecondary)) {
                        HStack {
                            Label("Recuerdos Registrados", systemImage: "brain.head.profile")
                                .foregroundColor(NewtonTheme.textPrimary)
                            Spacer()
                            Text("\(memoryManager.memories.count)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        
                        if memoryManager.memories.isEmpty {
                            Text("No hay recuerdos registrados aún. Newton aprende y guarda datos sobre ti de forma orgánica conforme conversas, o puedes añadirlos abajo.")
                                .font(.system(size: 12))
                                .foregroundColor(NewtonTheme.textSecondary)
                                .padding(.vertical, 2)
                        } else {
                            ForEach(memoryManager.memories) { mem in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(NewtonTheme.sand)
                                    
                                    Text(mem.content)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(NewtonTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                    
                                    Button {
                                        memoryManager.deleteMemory(id: mem.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(NewtonTheme.coralRed.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Instrucción o recuerdo para Newton...", text: $newMemoryInput)
                                .font(.system(size: 13))
                            
                            HStack(spacing: 12) {
                                Button {
                                    let trimmed = newMemoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        memoryManager.addMemory(trimmed)
                                        newMemoryInput = ""
                                        Haptics.success()
                                    }
                                } label: {
                                    Text("Añadir")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(NewtonTheme.sand)
                                }
                                .disabled(newMemoryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSynthesizingMemory)
                                
                                Spacer()
                                
                                Button {
                                    let trimmed = newMemoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    isSynthesizingMemory = true
                                    newMemoryInput = ""
                                    Haptics.medium()
                                    Task {
                                        let result = await memoryManager.synthesizeMemories(instruction: trimmed)
                                        await MainActor.run {
                                            isSynthesizingMemory = false
                                            synthesisStatusText = result
                                            Haptics.success()
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if isSynthesizingMemory {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text("Sintetizar con IA")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(NewtonTheme.sand)
                                }
                                .disabled(newMemoryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSynthesizingMemory)
                            }
                            
                            if let status = synthesisStatusText {
                                Text(status)
                                    .font(.system(size: 11))
                                    .foregroundColor(NewtonTheme.forestGreen)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        if !memoryManager.memories.isEmpty {
                            Button(role: .destructive) {
                                showingWipeMemoriesAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Borrar toda la memoria definitivamente")
                                }
                                .foregroundColor(NewtonTheme.coralRed)
                            }
                        }
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
            .alert("¿Borrar toda la memoria definitivamente?", isPresented: $showingWipeMemoriesAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Borrar Todo", role: .destructive) {
                    memoryManager.clearAllMemories()
                    Haptics.error()
                }
            } message: {
                Text("Esta acción eliminará permanentemente todos los recuerdos y hechos aprendidos por Newton Singularity.")
            }
        }
    }
}
