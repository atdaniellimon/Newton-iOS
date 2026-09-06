//
//  NewtonCodeDashboardView.swift
//  NewtonMac
//
//  Created for Newton Code on macOS.
//  Hero Analytics dashboard with Activity Heatmap and token tracking matching Claude Code.
//

import SwiftUI
import AppKit

public struct NewtonCodeDashboardView: View {
    @Binding public var inputPrompt: String
    @Binding public var isSidebarCollapsed: Bool
    public var onStartTask: (String) -> Void
    
    @ObservedObject private var workspace = NewtonCodeWorkspaceManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: String = "Overview" // "Overview" or "Models"
    @State private var timeRange: String = "All" // "All", "30d", "7d"
    
    private var isDark: Bool { colorScheme == .dark }
    
    public init(inputPrompt: Binding<String>, isSidebarCollapsed: Binding<Bool> = .constant(false), onStartTask: @escaping (String) -> Void) {
        self._inputPrompt = inputPrompt
        self._isSidebarCollapsed = isSidebarCollapsed
        self.onStartTask = onStartTask
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Header Bar
            topDashboardHeader
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header: What's up next, daniel?
                    HStack(spacing: 8) {
                        Text("What's up next, daniel?")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundColor(isDark ? Color(red: 0.94, green: 0.96, blue: 0.99) : Color(red: 0.08, green: 0.11, blue: 0.16))
                    }
                    .padding(.top, 16)
                    
                    // Analytics Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Top Header inside Card
                        HStack {
                            // Overview / Models Pills
                            HStack(spacing: 4) {
                                Button("Overview") { selectedTab = "Overview" }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(selectedTab == "Overview" ? (isDark ? Color.white : Color.black) : (isDark ? Color.gray : Color.secondary))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedTab == "Overview" ? (isDark ? Color(red: 0.22, green: 0.26, blue: 0.33) : Color(red: 0.88, green: 0.90, blue: 0.94)) : Color.clear)
                                    .clipShape(Capsule())
                                
                                Button("Models") { selectedTab = "Models" }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(selectedTab == "Models" ? (isDark ? Color.white : Color.black) : (isDark ? Color.gray : Color.secondary))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedTab == "Models" ? (isDark ? Color(red: 0.22, green: 0.26, blue: 0.33) : Color(red: 0.88, green: 0.90, blue: 0.94)) : Color.clear)
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            // Time Range Pills: All, 30d, 7d
                            HStack(spacing: 2) {
                                ForEach(["All", "30d", "7d"], id: \.self) { range in
                                    Button(range) { timeRange = range }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundColor(timeRange == range ? (isDark ? Color.white : Color.black) : (isDark ? Color.gray : Color.secondary))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(timeRange == range ? (isDark ? Color(red: 0.24, green: 0.28, blue: 0.35) : Color(red: 0.86, green: 0.88, blue: 0.92)) : Color.clear)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        
                        // 4 Essential Metrics Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            metricBox(title: "Sessions", value: "\(workspace.realTotalSessionsCount)")
                            metricBox(title: "Messages", value: "\(workspace.realTotalMessagesCount)")
                            metricBox(title: "Total tokens", value: workspace.realTotalTokensFormatted)
                            metricBox(title: "Favourite model", value: "Singularity")
                        }
                        
                        // Activity Heatmap Grid
                        heatmapGrid
                        
                        // Comparison footnote
                        Text("You've used ~6091× more tokens than War and Peace.")
                            .font(.system(size: 11))
                            .foregroundColor(isDark ? Color(red: 0.55, green: 0.60, blue: 0.68) : Color(red: 0.50, green: 0.55, blue: 0.62))
                    }
                    .padding(18)
                    .background(isDark ? Color(red: 0.12, green: 0.15, blue: 0.20) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isDark ? Color(red: 0.20, green: 0.24, blue: 0.32) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isDark ? 0.20 : 0.03), radius: 8, x: 0, y: 2)
                    
                    Spacer()
                }
                .padding(.horizontal, 36)
            }
            
            // Bottom Coding Input Bar
            NewtonCodeInputBar(
                text: $inputPrompt,
                isStreaming: false,
                onSend: {
                    let prompt = inputPrompt
                    inputPrompt = ""
                    onStartTask(prompt)
                },
                onStop: {}
            )
        }
        .background(isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : Color(red: 0.96, green: 0.97, blue: 0.99))
    }
    
    @ViewBuilder
    private var topDashboardHeader: some View {
        HStack(spacing: 10) {
            if isSidebarCollapsed {
                Color.clear
                    .frame(width: 68, height: 28)
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isSidebarCollapsed = false
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.84) : Color(red: 0.40, green: 0.45, blue: 0.52))
                        .frame(width: 28, height: 28)
                        .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.90, green: 0.92, blue: 0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Show Sidebar")
            }
            
            Text("Newton Code")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isDark ? Color(red: 0.94, green: 0.96, blue: 0.99) : Color(red: 0.08, green: 0.11, blue: 0.16))
            
            Text(workspace.activeProjectName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.45, green: 0.50, blue: 0.58))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.90, green: 0.92, blue: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            Spacer()
        }
        .padding(.horizontal, isSidebarCollapsed ? 12 : 24)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(height: 52)
        .overlay(
            Rectangle()
                .fill(isDark ? Color(red: 0.18, green: 0.22, blue: 0.28) : Color(red: 0.88, green: 0.90, blue: 0.94))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(isDark ? Color(red: 0.55, green: 0.60, blue: 0.68) : Color(red: 0.50, green: 0.55, blue: 0.62))
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isDark ? Color(red: 0.92, green: 0.94, blue: 0.98) : Color(red: 0.08, green: 0.11, blue: 0.16))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.95, green: 0.96, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    @ViewBuilder
    private var heatmapGrid: some View {
        let cols = 28
        let rows = 7
        
        HStack(spacing: 3.5) {
            ForEach(0..<cols, id: \.self) { c in
                VStack(spacing: 3.5) {
                    ForEach(0..<rows, id: \.self) { r in
                        let activeLevel = heatmapValueFor(col: c, row: r)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(level: activeLevel))
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }
    
    private func heatmapValueFor(col: Int, row: Int) -> Int {
        if col >= 20 {
            let seed = (col * 7 + row * 13) % 10
            return seed > 6 ? 3 : (seed > 3 ? 2 : 1)
        } else if col == 18 && row == 5 {
            return 2
        }
        return 0
    }
    
    private func heatmapColor(level: Int) -> Color {
        switch level {
        case 3:
            return Color(red: 0.30, green: 0.55, blue: 0.95) // Bright Blue
        case 2:
            return Color(red: 0.22, green: 0.40, blue: 0.75) // Mid Blue
        case 1:
            return Color(red: 0.16, green: 0.28, blue: 0.55) // Dark Blue
        default:
            return isDark ? Color(red: 0.17, green: 0.20, blue: 0.26) : Color(red: 0.88, green: 0.90, blue: 0.94) // Empty Gray
        }
    }
}
