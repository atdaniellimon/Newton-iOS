//
//  Theme.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI
import UIKit

public enum AppThemeMode: String, CaseIterable, Identifiable {
    case dark = "dark"
    case light = "light"
    case system = "system"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .dark: return "Dark (Everforest)"
        case .light: return "Light (Warm Canvas)"
        case .system: return "System Default"
        }
    }
    
    public var iconName: String {
        switch self {
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.righthalf.filled"
        }
    }
}

public struct NewtonTheme {
    // Dynamic Canvas Background
    public static let bg = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.15, blue: 0.16, alpha: 1.0)  // #1F2528 Deep Everforest
            : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0)  // #FAF8F2 Warm Paper
    })
    
    public static let bgDark = Color(red: 0.12, green: 0.15, blue: 0.16)
    public static let bgLight = Color(red: 0.98, green: 0.97, blue: 0.95)
    
    // Dynamic Cards / Surfaces
    public static let card = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.19, blue: 0.21, alpha: 1.0)  // #283136
            : UIColor(red: 0.94, green: 0.92, blue: 0.89, alpha: 1.0)  // #F0EBE3
    })
    
    public static let cardDark = Color(red: 0.16, green: 0.19, blue: 0.21)
    
    public static let surface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.24, blue: 0.26, alpha: 1.0)  // #333D42
            : UIColor(red: 0.90, green: 0.88, blue: 0.84, alpha: 1.0)  // #E6E0D6
    })
    
    public static let surfaceDark = Color(red: 0.20, green: 0.24, blue: 0.26)
    
    public static let border = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.26, green: 0.31, blue: 0.33, alpha: 0.8)  // #424E54
            : UIColor(red: 0.82, green: 0.79, blue: 0.74, alpha: 0.9)  // #D1C9BC
    })
    
    public static let borderDark = Color(red: 0.26, green: 0.31, blue: 0.33)
    
    // Accent Colors
    public static let sand = Color(red: 0.88, green: 0.74, blue: 0.50)          // #E0BD80
    public static let sandLight = Color(red: 0.95, green: 0.86, blue: 0.70)
    public static let forestGreen = Color(red: 0.65, green: 0.75, blue: 0.50)   // #A7C080
    public static let aqua = Color(red: 0.50, green: 0.73, blue: 0.70)          // #7FBBB3
    public static let coralRed = Color(red: 0.90, green: 0.49, blue: 0.50)      // #E67E80
    
    // Dynamic Typography
    public static let textPrimary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.81, blue: 0.72, alpha: 1.0)  // #D9CFB8
            : UIColor(red: 0.15, green: 0.18, blue: 0.20, alpha: 1.0)  // #262E33
    })
    
    public static let textSecondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.63, blue: 0.59, alpha: 1.0)  // #94A197
            : UIColor(red: 0.48, green: 0.52, blue: 0.49, alpha: 1.0)  // #7A857D
    })
    
    public static let textMuted = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.46, blue: 0.43, alpha: 1.0)
            : UIColor(red: 0.62, green: 0.65, blue: 0.62, alpha: 1.0)
    })
    
    // User Message Bubble Color
    public static let userBubble = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.88, green: 0.74, blue: 0.50, alpha: 1.0)
            : UIColor(red: 0.90, green: 0.80, blue: 0.62, alpha: 1.0)
    })
}

extension View {
    public func newtonCardStyle() -> some View {
        self
            .background(NewtonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 0.8)
            )
    }
}
