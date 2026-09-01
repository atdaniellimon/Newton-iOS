//
//  MacSettingsView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var apiKeyInput: String = ""
    @State private var baseUrlInput: String = ""
    
    public init() {}
    
    public var body: some View {
        TabView {
            // General Settings Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Provider & Model Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Provider & Model")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        Picker("Provider:", selection: $settings.currentProviderRaw) {
                            ForEach(AIProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("Model:", selection: $settings.currentModelId) {
                            ForEach(DefaultModelCatalog.models(for: settings.currentProvider)) { model in
                                Text("\(model.name) (\(model.id))").tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    // Credentials Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Credentials & Endpoints")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        HStack {
                            Text("API Key:")
                                .frame(width: 80, alignment: .leading)
                            SecureField("Enter API Key...", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Base URL:")
                                .frame(width: 80, alignment: .leading)
                            TextField("http://127.0.0.1:8000/v1", text: $baseUrlInput)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(spacing: 10) {
                            Button("Preset: Ollama") {
                                baseUrlInput = "http://127.0.0.1:11434/v1"
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Preset: LM Studio") {
                                baseUrlInput = "http://127.0.0.1:1234/v1"
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    // Generation Parameters Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Inference Parameters")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        HStack {
                            Text("Temperature: \(String(format: "%.2f", settings.temperature))")
                                .frame(width: 140, alignment: .leading)
                            Slider(value: $settings.temperature, in: 0.0...1.0, step: 0.05)
                        }
                        
                        HStack {
                            Text("Max Tokens: \(settings.maxTokens)")
                                .frame(width: 140, alignment: .leading)
                            Stepper("", value: $settings.maxTokens, in: 512...32768, step: 512)
                        }
                    }
                    .padding(14)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(20)
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            // About Tab
            VStack(spacing: 16) {
                Spacer()
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 72, height: 72)
                
                Text("Newton for macOS")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                
                Text("Version 1.0 (Universal Binary • Monterey 12.0+)")
                    .font(.system(size: 12))
                    .foregroundColor(NewtonTheme.textSecondary)
                
                Text("Designed for deep reasoning, mathematical analysis, and desktop automation.")
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .padding(30)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 480, height: 420)
        .onAppear {
            apiKeyInput = settings.getApiKey(for: settings.currentProvider)
            baseUrlInput = settings.customBaseUrl
        }
        .onChange(of: apiKeyInput) { newVal in
            settings.setApiKey(newVal, for: settings.currentProvider)
        }
        .onChange(of: baseUrlInput) { newVal in
            settings.customBaseUrl = newVal
        }
        .onChange(of: settings.currentProviderRaw) { _ in
            apiKeyInput = settings.getApiKey(for: settings.currentProvider)
        }
    }
}
