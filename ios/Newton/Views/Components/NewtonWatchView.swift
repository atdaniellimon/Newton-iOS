//
//  NewtonWatchView.swift
//  Newton
//
//  Created for Newton iOS.
//  Apple Watch companion interface and quick wrist query engine.
//

import SwiftUI
import WatchConnectivity

public struct NewtonWatchCompanionView: View {
    @StateObject private var watchManager = WatchConnectivityManager.shared
    @State private var quickPrompt: String = ""
    @State private var recentQueries: [String] = [
        "What is the theory of relativity?",
        "Write a quick Python sort function",
        "Summarize today's key insights"
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            // Watch Header
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .font(.system(size: 16))
                    .foregroundColor(NewtonTheme.sand)
                
                Text("Newton on Apple Watch")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(NewtonTheme.textPrimary)
                
                Spacer()
                
                Circle()
                    .fill(watchManager.isReachable ? NewtonTheme.forestGreen : NewtonTheme.textMuted)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Text(watchManager.isWatchAppInstalled ? "Connected & Synced with Apple Watch" : "Ready to pair with your Apple Watch")
                .font(.system(size: 12))
                .foregroundColor(NewtonTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            
            // Sync Button
            Button {
                Haptics.success()
                watchManager.syncConversationsToWatch()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Recent Chats to Watch")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(NewtonTheme.sand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(NewtonTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NewtonTheme.border, lineWidth: 0.8)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(NewtonTheme.card.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
    }
}
