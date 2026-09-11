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
                                    settingsRow(icon: "moon.stars", title: "Memories", badge: "\(memoryManager.memories.count)")
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
                                    settingsRow(icon: "slider.horizontal.3", title: "Capabilities")
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
    @ObservedObject var auth = AuthManager.shared

    var body: some View {
        Form {
            Section(header: Text("User profile")) {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(NewtonTheme.sand)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.username.isEmpty ? "Signed Out" : auth.username)
                            .font(.system(size: 17, weight: .semibold))
                        Text("Newton Singularity")
                            .font(.system(size: 13))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
                .padding(.vertical, 6)
            }

            Section(header: Text("Status & tier")) {
                HStack {
                    Text("Newton Tier")
                    Spacer()
                    Text(trialStatusText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(trialStatusColor)
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            Task { await auth.refreshUserInfo() }
        }
    }

    private var trialStatusText: String {
        guard let end = auth.trialEndsAt else { return "Active" }
        if end < Date() { return "Trial Ended" }
        return "Trial — \(Self.shortDate.string(from: end))"
    }

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private var trialStatusColor: Color {
        guard let end = auth.trialEndsAt else { return NewtonTheme.forestGreen }
        return end < Date() ? NewtonTheme.coralRed : NewtonTheme.sand
    }
}

// 2. Billing
struct BillingSubView: View {
    @ObservedObject var auth = AuthManager.shared

    var body: some View {
        Form {
            Section(header: Text("Subscription & Tokens")) {
                HStack {
                    Text("Plan")
                    Spacer()
                    Text("Newton Singularity")
                        .foregroundColor(NewtonTheme.sand)
                }
                HStack {
                    Text("Monthly Cost")
                    Spacer()
                    Text("$100.00 MXN / month")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                HStack {
                    Text("Credits Left")
                    Spacer()
                    Text(creditsLeft.formatted())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.forestGreen)
                }
            }

            Section(header: Text("Usage")) {
                HStack {
                    Text("Requests")
                    Spacer()
                    Text("\(auth.req5hUsed) / \(auth.req5hLimit)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
                HStack {
                    Text("Messages")
                    Spacer()
                    Text("\(auth.msgsWeekUsed) / \(auth.msgsWeekLimit)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
                HStack {
                    Text("Tokens (Weekly)")
                    Spacer()
                    Text("\(tokenShort) / \(tokenLimitShort)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
            }

            Section(footer: Text("Quota resets every 5 hours (rolling) and weekly on Monday 00:00.")) {
                EmptyView()
            }
        }
        .navigationTitle("Billing")
        .onAppear {
            Task { await auth.refreshUserInfo() }
        }
    }

    private var creditsLeft: Int {
        max(0, auth.creditsTotal - auth.creditsUsed)
    }

    private var tokenShort: String {
        Self.abbrev(auth.tokensWeekUsed)
    }
    private var tokenLimitShort: String {
        Self.abbrev(auth.tokensWeekLimit)
    }

    static func abbrev(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// 3. Notifications
struct NotificationsSubView: View {
    @State private var enableLiveActivity: Bool = true
    @State private var enableCompletionSounds: Bool = true
    
    var body: some View {
        Form {
            Section(header: Text("Alerts")) {
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
            Section(header: Text("Long-term memory")) {
                HStack {
                    Text("Registered memories")
                    Spacer()
                    Text("\(memoryManager.memories.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                if memoryManager.memories.isEmpty {
                    Text("No memories registered yet.")
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
            
            Section(header: Text("Add memories")) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Memory for Newton...", text: $newMemoryInput)
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
                            Text("Add")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        .disabled(newMemoryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSynthesizingMemory)
                        
                        Spacer()
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
                            Text("Delete all memories.")
                        }
                        .foregroundColor(NewtonTheme.coralRed)
                    }
                }
            }
        }
        .navigationTitle("Memories")
        .alert(isPresented: $showingWipeAlert) {
            Alert(
                title: Text("Delete all memories?"),
                message: Text("This action can not be reversed."),
                primaryButton: .destructive(Text("Delete everything")) {
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
            Section(header: Text("Storage Metrics")) {
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
            
            Section(header: Text("Cache")) {
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
            Section(header: Text("AI Model")) {
                Text("Newton Singularity")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(NewtonTheme.textPrimary)
            }

            Section(header: Text("Streaming")) {
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
            Section(header: Text("Speech rate & audio")) {
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
            
            Section(header: Text("Voice Engine")) {
                HStack {
                    Text("Engine")
                    Spacer()
                    Text("Enhanced Neural")
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
                Section(header: Text("About Newton")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (Universal)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("Newton Singularity")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(NewtonTheme.sand)
                    }
                }
                
                Section(header: Text("CREDITS")) {
                    Text("Designed & Built by Daniel Limon")
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
