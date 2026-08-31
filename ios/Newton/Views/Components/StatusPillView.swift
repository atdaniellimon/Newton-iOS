//
//  StatusPillView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct StatusPillView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(settings.isConfigured() ? NewtonTheme.forestGreen : NewtonTheme.coralRed)
                .frame(width: 7, height: 7)
            
            Text("\(settings.currentProvider.displayName) • \(shortModelName(settings.currentModelId))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(NewtonTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(NewtonTheme.surface.opacity(0.8))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(NewtonTheme.border, lineWidth: 0.7)
        )
    }
    
    private func shortModelName(_ modelId: String) -> String {
        if let last = modelId.split(separator: "/").last {
            return String(last)
        }
        return modelId
    }
}
