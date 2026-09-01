//
//  MacImageGenerationPlaceholderView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Stunning animated placeholder card shown while an AI image is being synthesized and rendered.
//

import SwiftUI

public struct MacImageGenerationPlaceholderView: View {
    public var prompt: String? = nil
    
    @State private var shimmerPhase: CGFloat = -1.0
    @State private var pulseScale: CGFloat = 0.95
    @State private var dotCount: Int = 1
    @State private var timer: Timer? = nil
    
    public init(prompt: String? = nil) {
        self.prompt = prompt
    }
    
    public var body: some View {
        ZStack {
            // Shimmering Canvas Background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NewtonTheme.card)
            
            // Animated Luminous Shimmer Wave
            GeometryReader { geo in
                let width = geo.size.width
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        NewtonTheme.sand.opacity(0.12),
                        Color.white.opacity(0.35),
                        NewtonTheme.sand.opacity(0.12),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.8)
                .offset(x: shimmerPhase * width)
                .blur(radius: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Content Core
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(NewtonTheme.sand.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulseScale)
                    
                    Circle()
                        .stroke(NewtonTheme.sand.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Text("Synthesizing visual artwork")
                            .font(.system(size: 13.5, weight: .medium, design: .serif))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        Text(String(repeating: ".", count: dotCount))
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(NewtonTheme.sand)
                            .frame(width: 18, alignment: .leading)
                    }
                    
                    if let p = prompt, !p.isEmpty {
                        Text("“\(p)”")
                            .font(.system(size: 11, design: .serif))
                            .foregroundColor(NewtonTheme.textSecondary)
                            .italic()
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Text("Diffusion model in progress • 1024×1024")
                            .font(.system(size: 10.5))
                            .foregroundColor(NewtonTheme.textTertiary)
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NewtonTheme.sand.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
            startDotAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startDotAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
            dotCount = (dotCount % 3) + 1
        }
    }
}
