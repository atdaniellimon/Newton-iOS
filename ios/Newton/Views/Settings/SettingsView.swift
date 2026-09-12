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
    @ObservedObject var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingInfoSheet: Bool = false
    @State private var showLogoutAlert: Bool = false
    
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
                            Text(L10n.tr("Account", es: "Cuenta"))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: ProfileSubView()) {
                                    settingsRow(icon: "person.crop.circle", title: L10n.tr("Profile", es: "Perfil"))
                                }
                                internalDivider
                                
                                NavigationLink(destination: BillingSubView()) {
                                    settingsRow(icon: "dollarsign.circle", title: L10n.tr("Billing", es: "Facturación"))
                                }
                                internalDivider
                                
                                NavigationLink(destination: NotificationsSubView()) {
                                    settingsRow(icon: "bell", title: L10n.tr("Notifications", es: "Notificaciones"))
                                }
                                internalDivider
                                
                                NavigationLink(destination: TimeAndFocusSubView()) {
                                    settingsRow(icon: "moon.stars", title: L10n.tr("Memories", es: "Memorias"), badge: "\(memoryManager.memories.count)")
                                }
                                internalDivider
                                
                                NavigationLink(destination: PrivacySubView()) {
                                    settingsRow(icon: "shield", title: L10n.tr("Privacy", es: "Privacidad"))
                                }
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - App Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("App", es: "Aplicación"))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: CapabilitiesSubView()) {
                                    settingsRow(icon: "slider.horizontal.3", title: L10n.tr("Capabilities", es: "Capacidades"))
                                }
                                internalDivider
                                
                                NavigationLink(destination: PermissionsSubView()) {
                                    settingsRow(icon: "switch.2", title: L10n.tr("Permissions", es: "Permisos"))
                                }
                                internalDivider
                                
                                NavigationLink(destination: VoiceSubView()) {
                                    settingsRow(icon: "waveform", title: L10n.tr("Voice", es: "Voz"))
                                }
                                internalDivider

                                // Language Selector row
                                HStack(spacing: 14) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(UIColor.label))
                                        .frame(width: 24)
                                    
                                    Text(L10n.tr("Language", es: "Idioma"))
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(Color(UIColor.label))
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $loc.language) {
                                        ForEach(AppLanguage.allCases) { lang in
                                            Text(lang.displayName).tag(lang)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(NewtonTheme.sand)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                internalDivider
                                
                                // Haptic Feedback direct toggle
                                HStack(spacing: 14) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(UIColor.label))
                                        .frame(width: 24)
                                    
                                    Text(L10n.tr("Haptic feedback", es: "Respuesta háptica"))
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
                            Text(L10n.tr("Appearance", es: "Apariencia"))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                            
                            AppearanceCardsSelector()
                                .padding(.horizontal, 16)
                        }
                        
                        // MARK: - Session Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("Session", es: "Sesión"))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                            
                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                HStack(spacing: 14) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(NewtonTheme.coralRed)
                                        .frame(width: 24)
                                    
                                    Text(L10n.tr("Log Out", es: "Cerrar Sesión"))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(NewtonTheme.coralRed)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.horizontal, 16)
                            
                            Text(L10n.tr("Logging out will securely remove all your chats, memories, and local data from this device.",
                                         es: "Al cerrar sesión se eliminarán todos tus chats, memorias y datos locales de este dispositivo."))
                                .font(.system(size: 12))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 24)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.tr("Settings", es: "Ajustes"))
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
            .alert(L10n.tr("Are you sure you want to log out?", es: "¿Cerrar Sesión?"), isPresented: $showLogoutAlert) {
                Button(L10n.tr("Cancel", es: "Cancelar"), role: .cancel) {}
                Button(L10n.tr("Log Out and Delete All", es: "Cerrar Sesión y Borrar Todo"), role: .destructive) {
                    dismiss()
                    AuthManager.shared.logout()
                }
            } message: {
                Text(L10n.tr("Logging out will remove all conversations, AI memories, and local data from this device.",
                             es: "Se eliminarán tus conversaciones, memorias de IA y datos locales de Newton en este dispositivo."))
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
            themeCard(mode: .light, title: L10n.tr("Light", es: "Claro")) {
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
            themeCard(mode: .dark, title: L10n.tr("Dark", es: "Oscuro")) {
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
            themeCard(mode: .system, title: L10n.tr("System", es: "Sistema")) {
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
    @ObservedObject var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutAlert: Bool = false

    var body: some View {
        Form {
            Section(header: Text(L10n.tr("User Profile", es: "Perfil de Usuario"))) {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(NewtonTheme.sand)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.username.isEmpty ? L10n.tr("Signed Out", es: "Sesión no iniciada") : auth.username)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        if !auth.email.isEmpty {
                            HStack(spacing: 4) {
                                Text(auth.email)
                                    .font(.system(size: 12))
                                    .foregroundColor(NewtonTheme.textSecondary)
                                if auth.emailVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(NewtonTheme.forestGreen)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Section(header: Text(L10n.tr("Status & Tier", es: "Estado y Plan"))) {
                HStack {
                    Text(L10n.tr("Newton Tier", es: "Plan Newton"))
                    Spacer()
                    Text(auth.tier.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(NewtonTheme.sand)
                }

                HStack {
                    Text(L10n.tr("Rate Limit", es: "Límite de Velocidad"))
                    Spacer()
                    Text("\(auth.rpmLimit) RPM")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(NewtonTheme.textSecondary)
                }

                HStack {
                    Text(L10n.tr("Status", es: "Estado"))
                    Spacer()
                    Text(tierStatusText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(tierStatusColor)
                }
            }

            Section {
                Button(role: .destructive, action: {
                    showLogoutAlert = true
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(L10n.tr("Log Out", es: "Cerrar Sesión"))
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundColor(NewtonTheme.coralRed)
                }
            } footer: {
                Text(L10n.tr("Logging out will securely remove all your chats, memories, and local data from this device.",
                             es: "Al cerrar sesión se eliminarán todos tus chats, memorias y datos locales de este dispositivo."))
                    .font(.system(size: 11))
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
        .navigationTitle(L10n.tr("Profile", es: "Perfil"))
        .onAppear {
            Task { await auth.refreshUserInfo() }
        }
        .alert(L10n.tr("Are you sure you want to log out?", es: "¿Cerrar Sesión?"), isPresented: $showLogoutAlert) {
            Button(L10n.tr("Cancel", es: "Cancelar"), role: .cancel) {}
            Button(L10n.tr("Log Out and Delete All", es: "Cerrar Sesión y Borrar Todo"), role: .destructive) {
                dismiss()
                auth.logout()
            }
        } message: {
            Text(L10n.tr("Logging out will remove all conversations, AI memories, and local data from this device.",
                         es: "Se eliminarán tus conversaciones, memorias de IA y datos locales de Newton en este dispositivo."))
        }
    }

    private var tierStatusText: String {
        guard let end = auth.trialEndsAt else { return L10n.tr("Active", es: "Activo") }
        if end < Date() { return L10n.tr("Expired", es: "Expirado") }
        return "\(L10n.tr("Active", es: "Activo")) — \(Self.shortDate.string(from: end))"
    }

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private var tierStatusColor: Color {
        guard let end = auth.trialEndsAt else { return NewtonTheme.forestGreen }
        return end < Date() ? NewtonTheme.coralRed : NewtonTheme.forestGreen
    }
}

// 2. Billing & Subscription
struct BillingSubView: View {
    @ObservedObject var auth = AuthManager.shared
    @ObservedObject var loc = LocalizationManager.shared
    @State private var showRotateConfirmation = false
    @State private var showRotationSuccessAlert = false

    var body: some View {
        Form {
            // Subscription Plan Card
            Section(header: Text(L10n.tr("Active Subscription", es: "Suscripción Activa"))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(auth.tier.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                
                                Text(auth.tier.badge.uppercased())
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(NewtonTheme.bg)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(NewtonTheme.sand)
                                    .clipShape(Capsule())
                            }
                            
                            Text(L10n.tr("$\(auth.tier.priceMXN).00 MXN / month", es: "$\(auth.tier.priceMXN).00 MXN / mes"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(NewtonTheme.sand)
                        }

                        Spacer()

                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(NewtonTheme.sand)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("PLAN FEATURES", es: "CARACTERÍSTICAS DEL PLAN"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(NewtonTheme.textMuted)

                        ForEach(auth.tier.localizedFeatures, id: \.self) { feat in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(NewtonTheme.forestGreen)
                                    .padding(.top, 2)
                                Text(feat)
                                    .font(.system(size: 12))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            // Quotas & Limits
            Section(header: Text(L10n.tr("Limits & Quotas (Rolling Windows)", es: "Límites y Cuotas (Rolling Windows)"))) {
                // 5-Hour limit
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.tr("5-Hour Window", es: "Ventana 5 Horas"))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(auth.quotaReq5h.used) / \(auth.quotaReq5h.limit) reqs")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(NewtonTheme.sand)
                    }
                    ProgressView(value: auth.quotaReq5h.percent)
                        .tint(quotaColor(for: auth.quotaReq5h.percent))
                }
                .padding(.vertical, 2)

                // Weekly Messages
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.tr("Weekly Messages", es: "Mensajes Semanales"))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(auth.quotaMsgsWeek.used) / \(auth.quotaMsgsWeek.limit)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(NewtonTheme.sand)
                    }
                    ProgressView(value: auth.quotaMsgsWeek.percent)
                        .tint(quotaColor(for: auth.quotaMsgsWeek.percent))
                }
                .padding(.vertical, 2)

                // Weekly Tokens
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.tr("Weekly Tokens", es: "Tokens Semanales"))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Self.abbrev(auth.quotaTokensWeek.used)) / \(Self.abbrev(auth.quotaTokensWeek.limit))")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(NewtonTheme.sand)
                    }
                    ProgressView(value: auth.quotaTokensWeek.percent)
                        .tint(quotaColor(for: auth.quotaTokensWeek.percent))
                }
                .padding(.vertical, 2)

                // Daily Images
                HStack {
                    Text(L10n.tr("Daily Images", es: "Imágenes Diarias"))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(auth.tier.dailyImagesUsed) / \(auth.tier.dailyImagesLimit)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(NewtonTheme.forestGreen)
                }
            }

            // Credits Balance
            Section(header: Text(L10n.tr("Credits Balance", es: "Balance de Créditos"))) {
                HStack {
                    Text(L10n.tr("Remaining Credits", es: "Créditos Restantes"))
                    Spacer()
                    Text(auth.creditsRemaining.formatted())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.forestGreen)
                }

                HStack {
                    Text(L10n.tr("Used Credits", es: "Créditos Usados"))
                    Spacer()
                    Text(auth.creditsUsed.formatted())
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }

            // API Key & Security
            Section(header: Text(L10n.tr("Security & API Key", es: "Seguridad y Clave API")),
                    footer: Text(L10n.tr("Rotating your API key invalidates the current key and generates a new one without losing credits.",
                                         es: "La rotación de clave invalida la clave actual y genera una nueva sin perder créditos."))) {
                HStack {
                    Text("API Key")
                    Spacer()
                    Text(maskedKey(auth.nwtnKey))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(NewtonTheme.textSecondary)
                }

                Button(role: .destructive) {
                    showRotateConfirmation = true
                } label: {
                    HStack {
                        if auth.isRotatingKey {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(L10n.tr("Rotate API Key", es: "Rotar API Key"))
                    }
                    .foregroundColor(NewtonTheme.sand)
                }
                .disabled(auth.isRotatingKey)
            }

            // Recent Usage Audit
            if !auth.recentUsageRecords.isEmpty {
                Section(header: Text(L10n.tr("Recent Usage Audit (/nwtn/usage/history)", es: "Auditoría de Uso Reciente (/nwtn/usage/history)"))) {
                    ForEach(auth.recentUsageRecords.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.endpoint)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                Text(Self.auditDate.string(from: record.date))
                                    .font(.system(size: 10))
                                    .foregroundColor(NewtonTheme.textMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(record.tokens) tok")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                                Text("HTTP \(record.status)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(NewtonTheme.forestGreen)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("Billing", es: "Facturación"))
        .alert(L10n.tr("Rotate API Key?", es: "¿Rotar API Key?"), isPresented: $showRotateConfirmation) {
            Button(L10n.tr("Cancel", es: "Cancelar"), role: .cancel) {}
            Button(L10n.tr("Rotate Key", es: "Rotar Clave"), role: .destructive) {
                Task {
                    let res = await auth.rotateApiKey()
                    if res.success {
                        showRotationSuccessAlert = true
                    }
                }
            }
        } message: {
            Text(L10n.tr("This will generate a new Bearer ntwn-... key and immediately revoke the previous one.",
                         es: "Esto generará una nueva clave Bearer ntwn-... y revocará la anterior de inmediato."))
        }
        .alert(L10n.tr("API Key Rotated Successfully", es: "Clave Rotada con Éxito"), isPresented: $showRotationSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.lastKeyRotationMessage ?? L10n.tr("Your new key has been securely stored in Keychain.",
                                                         es: "Tu nueva clave ha sido guardada en el Keychain de forma segura."))
        }
        .onAppear {
            Task {
                await auth.refreshUserInfo()
                await auth.fetchUsageHistory()
            }
        }
        .refreshable {
            await auth.refreshUserInfo()
            await auth.fetchUsageHistory()
        }
    }

    private func maskedKey(_ key: String) -> String {
        guard key.count > 10 else { return "••••••••" }
        let prefix = key.prefix(9)
        return "\(prefix)••••••••"
    }

    private func quotaColor(for percent: Double) -> Color {
        if percent > 0.9 { return NewtonTheme.coralRed }
        if percent > 0.75 { return NewtonTheme.sand }
        return NewtonTheme.forestGreen
    }

    static func abbrev(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    static let auditDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()
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
    @State private var showModelPicker = false
    
    var body: some View {
        Form {
            Section(header: Text(L10n.tr("AI Model", es: "Modelo de IA")),
                    footer: Text(L10n.tr("Models dynamically provided by Newton Gateway API (/nwtn/models).",
                                         es: "Modelos provistos dinámicamente por la API de Newton Gateway (/nwtn/models)."))) {
                Button {
                    showModelPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: settings.currentModel.iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(NewtonTheme.sand)
                            .frame(width: 32, height: 32)
                            .background(NewtonTheme.sand.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(settings.currentModelDisplayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(NewtonTheme.textPrimary)
                            Text(settings.currentModelId)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(NewtonTheme.textMuted)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Streaming")) {
                Toggle("Auto-Scroll During Generation", isOn: $settings.autoScrollOnStream)
                    .tint(NewtonTheme.sand)
            }
        }
        .navigationTitle("Capabilities")
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(selectedModelId: $settings.currentModelId)
        }
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
