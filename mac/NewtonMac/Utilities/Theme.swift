//
//  Theme.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

public struct NewtonTheme {
    // Brand Colors
    public static let obsidian = Color(red: 0.08, green: 0.10, blue: 0.11)
    public static let cream = Color(red: 0.98, green: 0.97, blue: 0.95)
    public static let sand = Color(red: 0.88, green: 0.74, blue: 0.50)
    public static let gold = Color(red: 0.95, green: 0.78, blue: 0.35)
    public static let forestGreen = Color(red: 0.22, green: 0.65, blue: 0.45)
    public static let coralRed = Color(red: 0.88, green: 0.35, blue: 0.30)
    
    // Adaptive Semantic Colors
    public static var background: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    public static var surface: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    public static var card: Color {
        Color(NSColor.underPageBackgroundColor)
    }
    
    public static var userBubble: Color {
        Color(red: 0.92, green: 0.86, blue: 0.76)
    }
    
    public static var textPrimary: Color {
        Color(NSColor.labelColor)
    }
    
    public static var textSecondary: Color {
        Color(NSColor.secondaryLabelColor)
    }
    
    public static var textTertiary: Color {
        Color(NSColor.tertiaryLabelColor)
    }
    
    public static var border: Color {
        Color(NSColor.separatorColor)
    }
}
