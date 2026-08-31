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
        case .light: return "Light (Warm Sand)"
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
    // Dynamic Background (Everforest dark vs Warm Paper light)
    public static let bg = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.17, blue: 0.19, alpha: 1.0)  // #232A2E
            : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0)  // #FAF8F2
    })
    
    public static let bgDark = Color(red: 0.14, green: 0.17, blue: 0.19)
    public static let bgLight = Color(red: 0.98, green: 0.97, blue: 0.95)
    
    // Dynamic Cards / Surfaces
    public static let card = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.21, blue: 0.23, alpha: 1.0)  // #2E383C
            : UIColor(red: 0.93, green: 0.91, blue: 0.88, alpha: 1.0)  // #EDE8E0
    })
    
    public static let cardDark = Color(red: 0.18, green: 0.21, blue: 0.23)
    
    public static let surface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.24, blue: 0.26, alpha: 1.0)  // #343E44
            : UIColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1.0)  // #E0DBD1
    })
    
    public static let surfaceDark = Color(red: 0.20, green: 0.24, blue: 0.26)
    
    public static let border = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.33, blue: 0.36, alpha: 1.0)  // #47545C
            : UIColor(red: 0.80, green: 0.77, blue: 0.72, alpha: 1.0)  // #CCC5B8
    })
    
    public static let borderDark = Color(red: 0.28, green: 0.33, blue: 0.36)
    
    // Accent Colors
    public static let sand = Color(red: 0.90, green: 0.76, blue: 0.52)          // #E6C384
    public static let sandLight = Color(red: 0.95, green: 0.86, blue: 0.70)
    public static let forestGreen = Color(red: 0.65, green: 0.75, blue: 0.50)   // #A7C080
    public static let aqua = Color(red: 0.50, green: 0.73, blue: 0.70)          // #7FBBB3
    public static let coralRed = Color(red: 0.90, green: 0.49, blue: 0.50)      // #E67E80
    public static let amber = Color(red: 0.85, green: 0.60, blue: 0.35)
    
    // Dynamic Typography Text
    public static let textPrimary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.83, green: 0.78, blue: 0.67, alpha: 1.0)  // #D3C6AA
            : UIColor(red: 0.18, green: 0.22, blue: 0.24, alpha: 1.0)  // #2D373D
    })
    
    public static let textSecondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.63, blue: 0.59, alpha: 1.0)  // #94A197
            : UIColor(red: 0.45, green: 0.49, blue: 0.46, alpha: 1.0)  // #737D76
    })
    
    public static let textMuted = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.49, blue: 0.46, alpha: 1.0)
            : UIColor(red: 0.60, green: 0.64, blue: 0.61, alpha: 1.0)
    })
    
    // Gradients
    public static let brandGradient = LinearGradient(
        colors: [sand, forestGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let messageUserGradient = LinearGradient(
        colors: [sand.opacity(0.85), sand],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
