//
//  SettingsView.swift
//  Newton
//
//  Modern, ultra-clean Settings screen structured after modern card hierarchy.
//

import SwiftUI
import Speech
import AVFoundation

public struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var syncService = iCloudSyncService.shared
    @ObservedObject var memoryManager = MemoryManager.shared
    @ObservedObject var endpointSync = EndpointSyncService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingInfoSheet: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        
                        // MARK: - Account Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: ProfileSubView()) {
                                    settingsRow(icon: "person.crop.circle", title: "Profile")
                                }
                                internalDivider
                                
                                NavigationLink(destination: BillingSubView()) {
                                    settingsRow(icon: "dollarsign.circle", title: "Billing")
                                }
                                internalDivider
                                
                                NavigationLink(destination: NotificationsSubView()) {
                                    settingsRow(icon: "bell", title: "Notifications")
                                }
                                internalDivider
                                
                                NavigationLink(destination: TimeAndFocusSubView()) {
                                    settingsRow(icon: "moon.stars", title: "Time & focus", badge: "\(memoryManager.memories.count)")
                                }
                                internalDivider
                                
                                NavigationLink(destination: PrivacySubView()) {
                                    settingsRow(icon: "shield", title: "Privacy")
                                }
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - App Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("App")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: CapabilitiesSubView()) {
                                    settingsRow(icon: "slider.horizontal.3", title: "Capabilities", badge: settings.currentModelId)
                                }
                                internalDivider
                                
                                NavigationLink(destination: PermissionsSubView()) {
                                    settingsRow(icon: "switch.2", title: "Permissions")
                                }
                                internalDivider
                                
                                NavigationLink(destination: VoiceSubView()) {
                                    settingsRow(icon: "waveform", title: "Voice")
                                }
                                internalDivider
                                
                                // Haptic Feedback direct toggle
                                HStack(spacing: 14) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(UIColor.label))
                                        .frame(width: 24)
                                    
                                    Text("Haptic feedback")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(Color(UIColor.label))
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $settings.hapticFeedbackEnabled)
                                        .labelsHidden()
                                        .tint(NewtonTheme.sand)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - Appearance Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Appearance")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                            
                            AppearanceCardsSelector()
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 24)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingInfoSheet = true
                    }) {
                        Image(systemName: "info")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingInfoSheet) {
                InfoSubView()
            }
        }
        .preferredColorScheme(settings.appTheme.colorScheme)
    }
    
    private func settingsRow(icon: String, title: String, badge: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(UIColor.label))
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(UIColor.label))
            
            Spacer()
            
            if let b = badge {
                Text(b)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NewtonTheme.sand)
                    .lineLimit(1)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
    
    private var internalDivider: some View {
        Divider()
            .padding(.leading, 54)
    }
}

// MARK: - Appearance Visual Cards Selector
struct AppearanceCardsSelector: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Light Card
            themeCard(mode: .light, title: "Light") {
                ZStack {
                    Color(UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0))
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)))
                            .frame(width: 38, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0)))
                            .frame(width: 26, height: 4)
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(10)
                }
            }
            
            // Dark Card
            themeCard(mode: .dark, title: "Dark") {
                ZStack {
                    Color(UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0))
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 38, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 26, height: 4)
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(10)
                }
            }
            
            // System Card
            themeCard(mode: .system, title: "System") {
                ZStack {
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                            path.closeSubpath()
                        }
                        .fill(Color(UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)))
                        
                        Path { path in
                            path.move(to: CGPoint(x: geo.size.width, y: 0))
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                            path.closeSubpath()
                        }
                        .fill(Color(UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)))
                            .frame(width: 38, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 26, height: 4)
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(10)
                }
            }
        }
    }
    
    private func themeCard<Content: View>(mode: AppThemeMode, title: String, @ViewBuilder content: () -> Content) -> some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                settings.appTheme = mode
            }
        }) {
            VStack(spacing: 8) {
                content()
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(settings.appTheme == mode ? Color.blue : Color.white.opacity(0.12), lineWidth: settings.appTheme == mode ? 2.5 : 1)
                    )
                
                Text(title)
                    .font(.system(size: 13, weight: settings.appTheme == mode ? .semibold : .regular))
                    .foregroundColor(settings.appTheme == mode ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subviews

// 1. Profile
struct ProfileSubView: View {
    var body: some View {
        Form {
            Section(header: Text("USER PROFILE")) {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(NewtonTheme.sand)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daniel Limón")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Developer & Entrepreneur")
                            .font(.system(size: 13))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
                .padding(.vertical, 6)
            }
            
            Section(header: Text("STATUS & TIER")) {
                HStack {
                    Text("Singularity Tier")
                    Spacer()
                    Text("Unlimited (Self-Hosted)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(NewtonTheme.forestGreen)
                }
            }
        }
        .navigationTitle("Profile")
    }
}

// 2. Billing
struct BillingSubView: View {
    var body: some View {
        Form {
            Section(header: Text("SUBSCRIPTION & TOKENS")) {
                HStack {
                    Text("Plan")
                    Spacer()
                    Text("Lifetime Private License")
                        .foregroundColor(NewtonTheme.sand)
                }
                HStack {
                    Text("Monthly Cost")
                    Spacer()
                    Text("$0.00 (Self-Hosted)")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            
            Section(footer: Text("Newton runs with your private Cloudflare Tunnel without third-party API metering.")) {
                EmptyView()
            }
        }
        .navigationTitle("Billing")
    }
}

// 3. Notifications
struct NotificationsSubView: View {
    @State private var enableLiveActivity: Bool = true
    @State private var enableCompletionSounds: Bool = true
    
    var body: some View {
        Form {
            Section(header: Text("ALERTS")) {
                Toggle("Live Activity Updates", isOn: $enableLiveActivity)
                    .tint(NewtonTheme.sand)
                Toggle("Completion Haptics", isOn: $enableCompletionSounds)
                    .tint(NewtonTheme.sand)
            }
        }
        .navigationTitle("Notifications")
    }
}

// 4. Time & Focus (Memory Manager)
struct TimeAndFocusSubView: View {
    @ObservedObject var memoryManager = MemoryManager.shared
    @State private var newMemoryInput: String = ""
    @State private var isSynthesizingMemory: Bool = false
    @State private var synthesisStatusText: String? = nil
    @State private var showingWipeAlert: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("MEMORIA PERSISTENTE (LONG-TERM MEMORY)")) {
                HStack {
                    Label("Recuerdos Registrados", systemImage: "brain.head.profile")
                    Spacer()
                    Text("\(memoryManager.memories.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                if memoryManager.memories.isEmpty {
                    Text("No hay recuerdos registrados aún. Newton aprende y guarda datos sobre ti de forma orgánica conforme conversas, o puedes añadirlos abajo.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding(.vertical, 4)
                } else {
                    ForEach(memoryManager.memories) { mem in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(NewtonTheme.sand)
                            
                            Text(mem.content)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            Button(action: {
                                memoryManager.deleteMemory(id: mem.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(NewtonTheme.coralRed.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            Section(header: Text("AÑADIR O SINTETIZAR CON IA")) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Instrucción o recuerdo para Newton...", text: $newMemoryInput)
                        .font(.system(size: 14))
                    
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
                                .font(.system(size: 13, weight: .semibold))
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
                            .font(.system(size: 13, weight: .semibold))
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
            }
            
            if !memoryManager.memories.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showingWipeAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Borrar toda la memoria definitivamente")
                        }
                        .foregroundColor(NewtonTheme.coralRed)
                    }
                }
            }
        }
        .navigationTitle("Time & focus")
        .alert(isPresented: $showingWipeAlert) {
            Alert(
                title: Text("¿Borrar toda la memoria definitivamente?"),
                message: Text("Esta acción eliminará permanentemente todos los recuerdos y hechos aprendidos por Newton."),
                primaryButton: .destructive(Text("Borrar Todo")) {
                    memoryManager.clearAllMemories()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// 5. Privacy & Storage
struct PrivacySubView: View {
    @ObservedObject var storage = StorageManager.shared
    @State private var showingClearCacheAlert: Bool = false
    @State private var cacheCleared: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("STORAGE METRICS")) {
                HStack {
                    Text("Total Conversations")
                    Spacer()
                    Text("\(storage.conversations.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                HStack {
                    Text("Total Messages Stored")
                    Spacer()
                    let count = storage.conversations.reduce(0) { $0 + $1.messages.count }
                    Text("\(count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
            }
            
            Section(header: Text("CACHE MANAGEMENT")) {
                Button(role: .destructive) {
                    URLCache.shared.removeAllCachedResponses()
                    cacheCleared = true
                    Haptics.success()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(cacheCleared ? "Cache Purged!" : "Clear Temporary Cache")
                    }
                    .foregroundColor(cacheCleared ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                }
            }
        }
        .navigationTitle("Privacy")
    }
}

// 6. Capabilities
struct CapabilitiesSubView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var endpointSync = EndpointSyncService.shared
    
    var body: some View {
        Form {
            Section(header: Text("AI MODEL SELECTION")) {
                Picker("Active Model", selection: $settings.currentModelId) {
                    ForEach(endpointSync.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
            
            Section(header: Text("STREAMING")) {
                Toggle("Auto-Scroll During Generation", isOn: $settings.autoScrollOnStream)
                    .tint(NewtonTheme.sand)
            }
        }
        .navigationTitle("Capabilities")
    }
}

// 7. Permissions
struct PermissionsSubView: View {
    @State private var micStatus: String = "Authorized"
    @State private var speechStatus: String = "Authorized"
    
    var body: some View {
        Form {
            Section(header: Text("DEVICE ACCESS PERMISSIONS")) {
                HStack {
                    Label("Microphone", systemImage: "mic.fill")
                    Spacer()
                    Text(micStatus)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(NewtonTheme.forestGreen)
                }
                
                HStack {
                    Label("Speech Recognition", systemImage: "waveform")
                    Spacer()
                    Text(speechStatus)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(NewtonTheme.forestGreen)
                }
            }
        }
        .navigationTitle("Permissions")
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: micStatus = "Authorized"
        case .denied: micStatus = "Denied"
        case .undetermined: micStatus = "Not Determined"
        @unknown default: break
        }
        
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speechStatus = "Authorized"
        case .denied: speechStatus = "Denied"
        case .restricted: speechStatus = "Restricted"
        case .notDetermined: speechStatus = "Not Determined"
        @unknown default: break
        }
    }
}

// 10. Voice
struct VoiceSubView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("SPEECH RATE & AUDIO")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speech Rate")
                        Spacer()
                        Text(String(format: "%.2fx", settings.speechRate * 2.0))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(NewtonTheme.sand)
                    }
                    
                    Slider(value: $settings.speechRate, in: 0.35...0.75, step: 0.05)
                        .tint(NewtonTheme.sand)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("VOICE ENGINE")) {
                HStack {
                    Text("Engine")
                    Spacer()
                    Text("AVSpeechSynthesizer (Enhanced Neural)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
        }
        .navigationTitle("Voice")
    }
}

// 11. Info Subview
struct InfoSubView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ABOUT NEWTON")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("6.0 (Universal)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("Newton Singularity Core")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(NewtonTheme.sand)
                    }
                }
                
                Section(header: Text("CREDITS")) {
                    Text("Designed & Built by Daniel Limón")
                        .font(.system(size: 14))
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(NewtonTheme.sand)
                }
            }
        }
    }
}
