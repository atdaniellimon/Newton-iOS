//
//  SettingsView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKeyInput: String = ""
    @State private var isApiKeyVisible: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResult: String? = nil
    @State private var testSuccess: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg
                    .ignoresSafeArea()
                
                Form {
                    // Status Badge Section
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(NewtonTheme.sand.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "bolt.horizontal.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Newton Singularity Engine")
                                    .font(.system(size: 14.5, weight: .bold, design: .serif))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                
                                Text("Connected to Cloud Endpoint")
                                    .font(.system(size: 11.5))
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
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Endpoint Info
                    Section(header: Text("CLOUD ENDPOINT").foregroundColor(NewtonTheme.textSecondary)) {
                        Text(SettingsManager.hardcodedEndpoint)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(NewtonTheme.textPrimary)
                            .lineLimit(1)
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Theme Mode Selector
                    Section(header: Text("APPEARANCE").foregroundColor(NewtonTheme.textSecondary)) {
                        Picker("Theme", selection: $settings.appTheme) {
                            ForEach(AppThemeMode.allCases) { mode in
                                Label(mode.displayName, systemImage: mode.iconName)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Optional Authorization
                    Section(header: Text("AUTHORIZATION (OPTIONAL)").foregroundColor(NewtonTheme.textSecondary),
                            footer: Text("Bearer token if required by proxy.")) {
                        HStack {
                            if isApiKeyVisible {
                                TextField("Optional API Key...", text: $apiKeyInput)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Optional API Key...", text: $apiKeyInput)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(NewtonTheme.textPrimary)
                            }
                            
                            Button(action: {
                                isApiKeyVisible.toggle()
                            }) {
                                Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                        }
                        .onChange(of: apiKeyInput) { newKey in
                            settings.setApiKey(newKey, for: settings.currentProvider)
                        }
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Test Connection
                    Section {
                        Button(action: testConnection) {
                            HStack {
                                Spacer()
                                if isTestingConnection {
                                    ProgressView()
                                        .tint(NewtonTheme.sand)
                                } else {
                                    Image(systemName: "bolt.fill")
                                    Text("Test Connection")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                            .foregroundColor(NewtonTheme.sand)
                        }
                        .disabled(isTestingConnection)
                        
                        if let result = testResult {
                            HStack(spacing: 8) {
                                Image(systemName: testSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(testSuccess ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                                Text(result)
                                    .font(.system(size: 12))
                                    .foregroundColor(testSuccess ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                            }
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
        }
        .onAppear {
            apiKeyInput = settings.currentApiKey
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            let dummyMsg = [Message(role: .user, content: "Ping")]
            do {
                let stream = LLMService.shared.streamCompletion(
                    messages: dummyMsg,
                    provider: settings.currentProvider,
                    modelId: settings.currentModelId,
                    baseUrl: SettingsManager.hardcodedEndpoint,
                    apiKey: apiKeyInput
                )
                
                var receivedAny = false
                for try await token in stream {
                    if !token.isEmpty {
                        receivedAny = true
                        break
                    }
                }
                
                await MainActor.run {
                    isTestingConnection = false
                    testSuccess = receivedAny
                    testResult = receivedAny ? "Connected to Newton Singularity Cloud!" : "Connected (No response body received)."
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    testSuccess = false
                    testResult = "Connection Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
