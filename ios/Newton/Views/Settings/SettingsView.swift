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
    @State private var showModelPicker: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg
                    .ignoresSafeArea()
                
                Form {
                    // Status Badge Section
                    Section {
                        HStack {
                            Circle()
                                .fill(settings.isConfigured() ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                                .frame(width: 10, height: 10)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(settings.isConfigured() ? "Connected to \(settings.currentProvider.displayName)" : "Configuration / API Key Required")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                
                                Text("Zero-Knowledge: API keys are securely stored in iOS Keychain.")
                                    .font(.system(size: 11))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
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
                    
                    // Provider Selection
                    Section(header: Text("AI PROVIDER").foregroundColor(NewtonTheme.textSecondary)) {
                        Picker("Provider", selection: $settings.currentProvider) {
                            ForEach(AIProvider.allCases) { provider in
                                Label(provider.displayName, systemImage: provider.iconName)
                                    .tag(provider)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: settings.currentProvider) { newProvider in
                            apiKeyInput = settings.getApiKey(for: newProvider)
                            testResult = nil
                        }
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // API Key Input
                    Section(header: Text("API KEY").foregroundColor(NewtonTheme.textSecondary)) {
                        HStack {
                            if isApiKeyVisible {
                                TextField("Paste your API Key", text: $apiKeyInput)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Paste your API Key", text: $apiKeyInput)
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
                    
                    // Base URL Input (for custom/local endpoints)
                    if settings.currentProvider.isCustomOrLocal {
                        Section(header: Text("BASE URL").foregroundColor(NewtonTheme.textSecondary),
                                footer: Text("Custom server endpoint (e.g. LM Studio, vLLM, Ollama or custom proxy)")
                            .font(.system(size: 11))
                            .foregroundColor(NewtonTheme.textMuted)) {
                            TextField("http://localhost:1234/v1", text: $settings.customBaseUrl)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(NewtonTheme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        }
                        .listRowBackground(NewtonTheme.card)
                    }
                    
                    // Model Selection
                    Section(header: Text("ACTIVE MODEL").foregroundColor(NewtonTheme.textSecondary)) {
                        Button(action: {
                            showModelPicker = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(settings.currentModelId)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(NewtonTheme.textPrimary)
                                    Text("Tap to change model")
                                        .font(.system(size: 11))
                                        .foregroundColor(NewtonTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // Hyperparameters
                    Section(header: Text("PARAMETERS").foregroundColor(NewtonTheme.textSecondary)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Temperature")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                Spacer()
                                Text(String(format: "%.1f", settings.temperature))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            Slider(value: $settings.temperature, in: 0.0...2.0, step: 0.1)
                                .tint(NewtonTheme.sand)
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Max Tokens")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                Spacer()
                                Text("\(settings.maxTokens)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            Slider(value: Binding(
                                get: { Double(settings.maxTokens) },
                                set: { settings.maxTokens = Int($0) }
                            ), in: 256...8192, step: 256)
                            .tint(NewtonTheme.sand)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(NewtonTheme.card)
                    
                    // System Prompt
                    Section(header: Text("CUSTOM SYSTEM PROMPT").foregroundColor(NewtonTheme.textSecondary)) {
                        TextEditor(text: $settings.customSystemPrompt)
                            .font(.system(size: 13))
                            .foregroundColor(NewtonTheme.textPrimary)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
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
                                Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
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
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(NewtonTheme.sand)
                }
            }
            .onAppear {
                apiKeyInput = settings.currentApiKey
            }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerSheet(selectedModelId: $settings.currentModelId)
            }
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        Haptics.light()
        
        Task {
            let testMessage = Message(role: .user, content: "Hello! Respond with the word Connected.")
            let provider = settings.currentProvider
            let modelId = settings.currentModelId
            let baseUrl = settings.effectiveBaseUrl(for: provider)
            let apiKey = settings.getApiKey(for: provider)
            
            do {
                let stream = LLMService.shared.streamCompletion(
                    messages: [testMessage],
                    provider: provider,
                    modelId: modelId,
                    baseUrl: baseUrl,
                    apiKey: apiKey,
                    maxTokens: 50
                )
                
                var responseText = ""
                for try await token in stream {
                    responseText += token
                    if !responseText.isEmpty { break }
                }
                
                testSuccess = true
                testResult = "Connection successful! Received response."
                Haptics.success()
            } catch {
                testSuccess = false
                testResult = "Connection failed: \(error.localizedDescription)"
                Haptics.error()
            }
            
            isTestingConnection = false
        }
    }
}
