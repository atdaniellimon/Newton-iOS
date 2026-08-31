//
//  Hero3DCanvasView.swift
//  Newton
//
//  Created for Newton iOS.
//  Native SwiftUI 120Hz GPU implementation of Newton's 3D Kinetic Undulating Wave Grid.
//

import SwiftUI

public struct Hero3DCanvasView: View {
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let cx = w / 2
                let cy = h * 0.65
                
                let rows = 26
                let cols = 26
                let gridSpacing: CGFloat = 34
                let cameraHeight: CGFloat = 260
                let fov: CGFloat = 380
                
                var gridPoints: [[CGPoint]] = Array(repeating: Array(repeating: .zero, count: cols), count: rows)
                
                for r in 0..<rows {
                    for c in 0..<cols {
                        let xWorld = (CGFloat(c) - CGFloat(cols) / 2.0) * gridSpacing
                        let zWorld = CGFloat(r) * gridSpacing + 40
                        
                        // Undulating wave equation matching Newton Three.js engine
                        let u = Double(xWorld) * 0.035
                        let v = Double(zWorld) * 0.035
                        let wave = sin(u + time * 0.85) * cos(v + time * 0.85) * 28.0
                        let yWorld = wave - 20.0
                        
                        // 3D Perspective Projection
                        let depth = zWorld
                        guard depth > 10 else { continue }
                        let scale = fov / (fov + depth)
                        
                        let xProj = cx + xWorld * scale
                        let yProj = cy + (cameraHeight - yWorld) * scale
                        
                        gridPoints[r][c] = CGPoint(x: xProj, y: yProj)
                    }
                }
                
                // Draw Wireframe Lines (Horizontal & Vertical)
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
                    let depthFactor = 1.0 - Double(r) / Double(rows)
                    let alpha = max(0.02, depthFactor * 0.18)
                    context.stroke(path, with: .color(NewtonTheme.sand.opacity(alpha)), lineWidth: 0.8)
                }
                
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
                    let alpha = 0.09
                    context.stroke(path, with: .color(NewtonTheme.textSecondary.opacity(alpha)), lineWidth: 0.6)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
