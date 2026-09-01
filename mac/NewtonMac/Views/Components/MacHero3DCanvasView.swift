//
//  MacHero3DCanvasView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  120Hz GPU-accelerated 3D Undulating Kinetic Wave Grid covering 50%+ of the screen.
//

import SwiftUI
import AppKit

public struct MacHero3DCanvasView: View {
    public var isThinking: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(isThinking: Bool = false) {
        self.isThinking = isThinking
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let isDark = colorScheme == .dark
            let speedMultiplier = isThinking ? 1.6 : 0.8
            
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let cx = w / 2.0
                // Position waves to cover the bottom 55% of the screen
                let cy = h * 0.44
                
                let rows = 48
                let cols = 42
                let gridSpacing: CGFloat = 32.0
                let cameraHeight: CGFloat = 220.0
                let fov: CGFloat = 440.0
                
                var gridPoints: [[CGPoint]] = Array(repeating: Array(repeating: .zero, count: cols), count: rows)
                
                for r in 0..<rows {
                    for c in 0..<cols {
                        let xWorld = (CGFloat(c) - CGFloat(cols) / 2.0) * gridSpacing
                        let zWorld = CGFloat(r) * gridSpacing + 20.0
                        
                        // Dynamic Harmonic Kinetic Wave Equation
                        let u = Double(xWorld) * 0.028
                        let v = Double(zWorld) * 0.028
                        let wave = sin(u + time * speedMultiplier) * cos(v + time * speedMultiplier) * 44.0
                        let yWorld = wave - 14.0
                        
                        let depth = zWorld
                        guard depth > 5 else { continue }
                        let scale = fov / (fov + depth)
                        
                        let xProj = cx + xWorld * scale
                        let yProj = cy + (cameraHeight - yWorld) * scale
                        
                        gridPoints[r][c] = CGPoint(x: xProj, y: yProj)
                    }
                }
                
                // Draw Horizontal Wave Lines
                for r in 0..<rows {
                    var path = Path()
                    var started = false
                    for c in 0..<cols {
                        let pt = gridPoints[r][c]
                        if pt != .zero {
                            if !started {
                                path.move(to: pt)
                                started = true
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                    }
                    
                    let depthRatio = 1.0 - Double(r) / Double(rows)
                    let alpha = max(0.04, depthRatio * (isDark ? 0.38 : 0.28))
                    let lineColor = isDark ? NewtonTheme.sand : Color(red: 0.28, green: 0.34, blue: 0.42)
                    context.stroke(path, with: .color(lineColor.opacity(alpha)), lineWidth: 0.95)
                }
                
                // Draw Vertical Perspective Lines
                for c in 0..<cols {
                    var path = Path()
                    var started = false
                    for r in 0..<rows {
                        let pt = gridPoints[r][c]
                        if pt != .zero {
                            if !started {
                                path.move(to: pt)
                                started = true
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                    }
                    let alpha = isDark ? 0.16 : 0.12
                    let lineColor = isDark ? NewtonTheme.forestGreen : Color(red: 0.38, green: 0.44, blue: 0.52)
                    context.stroke(path, with: .color(lineColor.opacity(alpha)), lineWidth: 0.7)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
