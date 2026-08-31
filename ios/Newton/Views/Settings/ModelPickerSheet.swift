//
//  ModelPickerSheet.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct ModelPickerSheet: View {
    @Binding public var selectedModelId: String
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var customModelText: String = ""
    @State private var searchText: String = ""
    
    public init(selectedModelId: Binding<String>) {
        self._selectedModelId = selectedModelId
    }
    
    private var availableModels: [AIModel] {
        let list = DefaultModelCatalog.models(for: settings.currentProvider)
        if searchText.isEmpty {
            return list
        }
        return list.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bgDark
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(NewtonTheme.textSecondary)
                        TextField("Search models...", text: $searchText)
                            .foregroundColor(NewtonTheme.textPrimary)
                    }
                    .padding(10)
                    .background(NewtonTheme.surfaceDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(NewtonTheme.borderDark, lineWidth: 0.8)
                    )
                    .padding(.horizontal, 16)
                    
                    // Custom Model ID Entry
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Model ID:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(NewtonTheme.textSecondary)
                        
                        HStack {
                            TextField("e.g. claude-3-7-sonnet-20250219", text: $customModelText)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(NewtonTheme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            
                            if !customModelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button("Apply") {
                                    Haptics.success()
                                    selectedModelId = customModelText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    dismiss()
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(NewtonTheme.sand)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(10)
                        .background(NewtonTheme.surfaceDark)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NewtonTheme.borderDark, lineWidth: 0.8)
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // Models List
                    List {
                        Section(header: Text("PRESET MODELS FOR \(settings.currentProvider.displayName.uppercased())")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(NewtonTheme.textSecondary)
                        ) {
                            ForEach(availableModels) { model in
                                Button(action: {
                                    Haptics.selection()
                                    selectedModelId = model.id
                                    dismiss()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: model.iconName)
                                            .font(.system(size: 14))
                                            .foregroundColor(selectedModelId == model.id ? NewtonTheme.sand : NewtonTheme.textSecondary)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(NewtonTheme.textPrimary)
                                            
                                            if !model.description.isEmpty {
                                                Text(model.description)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(NewtonTheme.textSecondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedModelId == model.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(NewtonTheme.sand)
                                        }
                                    }
                                }
                                .listRowBackground(NewtonTheme.cardDark)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .padding(.top, 10)
            }
            .navigationTitle("Select Model")
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
                customModelText = selectedModelId
            }
        }
    }
}
