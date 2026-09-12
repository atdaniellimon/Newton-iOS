//
//  ModelPickerSheet.swift
//  Newton
//
//  Dynamic AI Model Picker backed by the Newton Labs Gateway API (/nwtn/models).
//

import SwiftUI

public struct ModelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModelId: String
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var endpointSync = EndpointSyncService.shared
    @ObservedObject var auth = AuthManager.shared
    @State private var isRefreshing = false
    @State private var showTierAlert = false
    @State private var restrictedModelName = ""

    public init(selectedModelId: Binding<String>) {
        self._selectedModelId = selectedModelId
    }

    private var activeModels: [AIModel] {
        if !endpointSync.models.isEmpty {
            return endpointSync.models
        }
        if !settings.availableModels.isEmpty {
            return settings.availableModels
        }
        return DefaultModelCatalog.models()
    }

    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header status card
                        apiStatusBanner

                        // Models list
                        VStack(spacing: 12) {
                            ForEach(activeModels) { model in
                                modelCard(for: model)
                            }
                        }

                        // API Info
                        gatewayInfoFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .refreshable {
                    await refreshModels()
                }
            }
            .navigationTitle("Modelos Newton")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refreshModels() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: NewtonTheme.sand))
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(NewtonTheme.sand)
                        }
                    }
                    .disabled(isRefreshing)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(NewtonTheme.sand)
                }
            }
        }
        .alert("Mejora de Plan Requerida", isPresented: $showTierAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("El modelo '\(restrictedModelName)' requiere el plan Newton Pro o Matrix. Consulta los detalles de suscripción en Billing.")
        }
        .task {
            if endpointSync.models.isEmpty {
                await refreshModels()
            }
        }
    }

    // MARK: - Subviews

    private var apiStatusBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(endpointSync.isServerOnline ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(endpointSync.isServerOnline ? "Newton Gateway Conectado" : "Gateway Desconectado")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NewtonTheme.textPrimary)

                Text(endpointSync.isServerOnline
                     ? "\(activeModels.count) modelos disponibles · \(endpointSync.serverLatencyMs.map { "\($0) ms" } ?? "en línea")"
                     : "Usando modelos en caché local")
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.textSecondary)
            }

            Spacer()

            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NewtonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
    }

    private func modelCard(for model: AIModel) -> some View {
        let isSelected = selectedModelId == model.id
        let isAllowed = auth.tier.canUseModel(model.id)

        return Button {
            if !isAllowed {
                restrictedModelName = model.name
                showTierAlert = true
                Haptics.error()
                return
            }
            Haptics.selection()
            selectedModelId = model.id
            settings.currentModelId = model.id
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Icon Badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? NewtonTheme.sand.opacity(0.18) : NewtonTheme.surface)
                            .frame(width: 42, height: 42)

                        Image(systemName: model.iconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isSelected ? NewtonTheme.sand : NewtonTheme.textPrimary)
                    }

                    // Model Name & Engine
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(model.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(NewtonTheme.textPrimary)

                            if isSelected {
                                Text("ACTIVO")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(NewtonTheme.bg)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(NewtonTheme.sand)
                                    .clipShape(Capsule())
                            } else if !isAllowed {
                                Text("REQUIERE PRO")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(NewtonTheme.coralRed)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(NewtonTheme.coralRed.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(model.id)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }

                    Spacer()

                    // Selection Checkmark
                    ZStack {
                        Circle()
                            .stroke(isSelected ? NewtonTheme.sand : NewtonTheme.border, lineWidth: 1.5)
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Circle()
                                .fill(NewtonTheme.sand)
                                .frame(width: 14, height: 14)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(NewtonTheme.bg)
                        }
                    }
                }

                // Description
                if !model.description.isEmpty {
                    Text(model.description)
                        .font(.system(size: 13))
                        .foregroundColor(NewtonTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Capabilities Pills
                if !model.capabilities.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(model.capabilities, id: \.self) { cap in
                            HStack(spacing: 4) {
                                Image(systemName: iconForCapability(cap))
                                    .font(.system(size: 9))
                                Text(cap.capitalized)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(NewtonTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(NewtonTheme.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(NewtonTheme.border, lineWidth: 0.6)
                            )
                        }

                        Spacer()

                        Text(model.ownedBy)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(NewtonTheme.textMuted)
                    }
                }
            }
            .padding(14)
            .background(NewtonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? NewtonTheme.sand : NewtonTheme.border, lineWidth: isSelected ? 1.5 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var gatewayInfoFooter: some View {
        VStack(spacing: 4) {
            Text("Newton Gateway · Singularity Core Engine")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(NewtonTheme.textMuted)

            Text("Endpoint: api.newton.daniellimon.uk/nwtn/models")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(NewtonTheme.textMuted.opacity(0.8))
        }
        .padding(.top, 10)
    }

    private func iconForCapability(_ capability: String) -> String {
        switch capability.lowercased() {
        case "chat":
            return "bubble.left.and.bubble.right.fill"
        case "code":
            return "chevron.left.forwardslash.chevron.right"
        case "vision":
            return "eye.fill"
        case "images":
            return "photo.fill"
        default:
            return "sparkles"
        }
    }

    private func refreshModels() async {
        isRefreshing = true
        await endpointSync.fetchAvailableModels()
        isRefreshing = false
    }
}
