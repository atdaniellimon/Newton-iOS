//
//  ThinkingOrbView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Native SwiftUI 120Hz GPU implementation of Newton's Dotted 3D Thought-Orb.
//

import SwiftUI
import AppKit

public struct ThinkingOrbView: View {
    public let size: CGFloat
    public let style: OrbStyle
    @Environment(\.colorScheme) private var colorScheme
    
    public enum OrbStyle {
        case globe
        case orbits
    }
    
    public init(size: CGFloat = 32, style: OrbStyle = .globe) {
        self.size = size
        self.style = style
    }
    
    private struct ProjectedDot {
        let x: CGFloat
        let y: CGFloat
        let z: CGFloat
        let radius: CGFloat
        let alpha: Double
        let isHighlight: Bool
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let isDark = colorScheme == .dark
            
            Canvas { context, canvasSize in
                let cx = canvasSize.width / 2
                let cy = canvasSize.height / 2
                let sphereRadius = min(cx, cy) * 0.82
                
                var dots: [ProjectedDot] = []
                
                if style == .globe {
                    // Globe mode: Latitude and Longitude rotating sphere with scan beam
                    let rotY = time * 0.95
                    let rotX = 0.35 + 0.08 * sin(time * 0.4)
                    let scanPos = time * 1.4
                    
                    let sinY = sin(rotY), cosY = cos(rotY)
                    let sinX = sin(rotX), cosX = cos(rotX)
                    
                    let latRings = 14
                    let lonDensity = 28
                    
                    for p in 0...latRings {
                        let lat = -Double.pi / 2.0 + (Double(p) / Double(latRings)) * Double.pi
                        let cosLat = cos(lat), sinLat = sin(lat)
                        let count = max(1, Int(abs(cosLat) * Double(lonDensity)))
                        
                        for v in 0..<count {
                            let lon = (Double(v) / Double(count)) * 2.0 * Double.pi
                            let x0 = cosLat * cos(lon)
                            let y0 = sinLat
                            let z0 = cosLat * sin(lon)
                            
                            // 3D rotation
                            let rx = x0 * cosX + z0 * sinX
                            let rz = -x0 * sinX + z0 * cosX
                            let ry = y0 * cosY - rz * sinY
                            let rz2 = y0 * sinY + rz * cosY
                            
                            let depthFactor = (rz2 + 1.0) / 2.0
                            guard depthFactor > 0.05 else { continue }
                            
                            // Scan highlight pulse
                            let diff = atan2(sin(lon + rotY - scanPos), cos(lon + rotY - scanPos))
                            let scanHighlight = exp(-(diff * diff) / 0.22) * max(0, rz2)
                            
                            let px = cx + CGFloat(rx) * sphereRadius
                            let py = cy - CGFloat(ry) * sphereRadius
                            let rDot = (0.7 + 1.6 * depthFactor + scanHighlight * 1.5) * (size / 100.0)
                            let alpha = max(0.15, min(1.0, 0.25 + 0.75 * depthFactor + scanHighlight * 0.6))
                            
                            dots.append(ProjectedDot(
                                x: px,
                                y: py,
                                z: CGFloat(rz2),
                                radius: CGFloat(rDot),
                                alpha: alpha,
                                isHighlight: scanHighlight > 0.35
                            ))
                        }
                    }
                } else {
                    // Orbits mode: Concentric revolving particle rings
                    let orbitCount = 8
                    let pointsPerOrbit = 22
                    
                    for b in 0..<orbitCount {
                        let orbitR = sphereRadius * (0.45 + 0.55 * (Double(b) / Double(orbitCount)))
                        let tilt = Double(b) * 0.45 + time * 0.15
                        let speed = (0.6 + Double(b) * 0.2) * (b % 2 == 0 ? 1.0 : -1.0)
                        
                        for c in 0..<pointsPerOrbit {
                            let angle = (Double(c) / Double(pointsPerOrbit)) * 2.0 * Double.pi + time * speed
                            let x0 = cos(angle) * orbitR
                            let y0 = sin(angle) * orbitR * sin(tilt)
                            let z0 = sin(angle) * orbitR * cos(tilt)
                            
                            let depthFactor = (z0 / Double(sphereRadius) + 1.0) / 2.0
                            guard depthFactor > 0.05 else { continue }
                            
                            let px = cx + CGFloat(x0)
                            let py = cy + CGFloat(y0)
                            let rDot = (0.8 + 1.4 * depthFactor) * (size / 100.0)
                            let alpha = max(0.2, min(1.0, 0.3 + 0.7 * depthFactor))
                            
                            dots.append(ProjectedDot(
                                x: px,
                                y: py,
                                z: CGFloat(z0),
                                radius: CGFloat(rDot),
                                alpha: alpha,
                                isHighlight: false
                            ))
                        }
                    }
                }
                
                // Sort by depth (Z-buffer)
                dots.sort { $0.z < $1.z }
                
                // Draw dots
                for dot in dots {
                    let rect = CGRect(
                        x: dot.x - dot.radius,
                        y: dot.y - dot.radius,
                        width: dot.radius * 2,
                        height: dot.radius * 2
                    )
                    
                    let dotColor: Color
                    if dot.isHighlight {
                        dotColor = isDark ? NewtonTheme.sand : Color(red: 0.15, green: 0.18, blue: 0.22)
                    } else {
                        dotColor = isDark ? NewtonTheme.sand.opacity(0.85) : Color(red: 0.35, green: 0.40, blue: 0.48)
                    }
                    
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor.opacity(dot.alpha)))
                }
            }
        }
        .frame(width: size, height: size)
    }
}
