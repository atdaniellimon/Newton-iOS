//
//  Theme.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct NewtonTheme {
    // Primary palette
    public static let bgDark = Color(red: 0.14, green: 0.17, blue: 0.19)       // #232A2E
    public static let cardDark = Color(red: 0.18, green: 0.21, blue: 0.23)     // #2E383C
    public static let surfaceDark = Color(red: 0.20, green: 0.24, blue: 0.26)  // #343E44
    public static let borderDark = Color(red: 0.28, green: 0.33, blue: 0.36)   // #47545C
    
    // Accent colors
    public static let sand = Color(red: 0.90, green: 0.76, blue: 0.52)         // #E6C384
    public static let sandLight = Color(red: 0.95, green: 0.86, blue: 0.70)
    public static let forestGreen = Color(red: 0.65, green: 0.75, blue: 0.50)  // #A7C080
    public static let aqua = Color(red: 0.50, green: 0.73, blue: 0.70)         // #7FBBB3
    public static let coralRed = Color(red: 0.90, green: 0.49, blue: 0.50)     // #E67E80
    public static let amber = Color(red: 0.85, green: 0.60, blue: 0.35)
    
    // Typography colors
    public static let textPrimary = Color(red: 0.83, green: 0.78, blue: 0.67)  // #D3C6AA
    public static let textSecondary = Color(red: 0.58, green: 0.63, blue: 0.59)// #94A197
    public static let textMuted = Color(red: 0.45, green: 0.49, blue: 0.46)
    
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
            .background(NewtonTheme.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NewtonTheme.borderDark, lineWidth: 0.8)
            )
    }
}
