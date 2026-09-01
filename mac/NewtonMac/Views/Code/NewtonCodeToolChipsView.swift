//
//  NewtonCodeToolChipsView.swift
//  NewtonMac
//
//  Created for Newton Code on macOS.
//  Collapsible tool chips matching Claude Code style.
//

import SwiftUI
import AppKit

public struct CodeToolChipView: View {
    public let title: String
    public let details: String
    public var iconName: String = "chevron.right"
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(isDark ? Color(red: 0.78, green: 0.82, blue: 0.88) : Color(red: 0.35, green: 0.40, blue: 0.48))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isDark ? Color(red: 0.55, green: 0.60, blue: 0.68) : Color(red: 0.50, green: 0.55, blue: 0.62))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isDark ? Color(red: 0.15, green: 0.18, blue: 0.23) : Color(red: 0.92, green: 0.94, blue: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isDark ? Color(red: 0.22, green: 0.26, blue: 0.33) : Color(red: 0.85, green: 0.88, blue: 0.92), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            
            if isExpanded && !details.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(details)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(isDark ? Color(red: 0.88, green: 0.91, blue: 0.96) : Color(red: 0.12, green: 0.15, blue: 0.20))
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(isDark ? Color(red: 0.10, green: 0.12, blue: 0.16) : Color(red: 0.96, green: 0.97, blue: 0.99))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isDark ? Color(red: 0.20, green: 0.24, blue: 0.30) : Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 0.8)
                )
            }
        }
        .padding(.vertical, 2)
    }
}

public struct CodeBashExecutionCardView: View {
    public let command: String
    public var onRun: (() -> Void)? = nil
    @State private var copied: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    public var body: some View {
        HStack(spacing: 8) {
            Text("bash")
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.98))
            
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 0.92, green: 0.95, blue: 0.99) : Color(red: 0.10, green: 0.13, blue: 0.18))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Run Play button
            if let onRun = onRun {
                Button(action: onRun) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(NewtonTheme.sand)
                        .frame(width: 22, height: 22)
                        .background(isDark ? Color(red: 0.20, green: 0.24, blue: 0.31) : Color(red: 0.88, green: 0.91, blue: 0.95))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Run in Terminal")
            }
            
            // Copy command
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            }) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(copied ? NewtonTheme.forestGreen : (isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.45, green: 0.50, blue: 0.58)))
            }
            .buttonStyle(.plain)
            .help("Copy command")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isDark ? Color(red: 0.12, green: 0.15, blue: 0.20) : Color(red: 0.93, green: 0.95, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDark ? Color(red: 0.22, green: 0.26, blue: 0.34) : Color(red: 0.86, green: 0.89, blue: 0.93), lineWidth: 0.8)
        )
        .padding(.vertical, 4)
    }
}
