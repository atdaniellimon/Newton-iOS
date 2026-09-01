//
//  MacHero3DCanvasView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import SceneKit

public struct MacHero3DCanvasView: View {
    public var isThinking: Bool = false
    public var isSpeaking: Bool = false
    
    public init(isThinking: Bool = false, isSpeaking: Bool = false) {
        self.isThinking = isThinking
        self.isSpeaking = isSpeaking
    }
    
    public var body: some View {
        SceneView(
            scene: makeScene(),
            options: [.allowsCameraControl, .autoenablesDefaultLighting]
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        
        let sphere = SCNSphere(radius: 1.2)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0.88, green: 0.74, blue: 0.50, alpha: 0.95)
        material.emission.contents = isThinking ? NSColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 0.8) : NSColor(red: 0.35, green: 0.30, blue: 0.20, alpha: 0.4)
        material.roughness.contents = 0.2
        material.metalness.contents = 0.8
        sphere.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(0, 0, 0)
        
        let spin = CABasicAnimation(keyPath: "rotation")
        spin.toValue = NSValue(scnVector4: SCNVector4(x: 0.2, y: 1.0, z: 0.1, w: CGFloat.pi * 2))
        spin.duration = isThinking ? 4 : 12
        spin.repeatCount = .infinity
        sphereNode.addAnimation(spin, forKey: "spin")
        
        scene.rootNode.addChildNode(sphereNode)
        
        // Ambient Light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(white: 0.5, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Omni Light
        let omniLight = SCNLight()
        omniLight.type = .omni
        omniLight.color = NSColor(red: 0.95, green: 0.85, blue: 0.65, alpha: 1.0)
        let omniNode = SCNNode()
        omniNode.light = omniLight
        omniNode.position = SCNVector3(x: 3, y: 5, z: 6)
        scene.rootNode.addChildNode(omniNode)
        
        return scene
    }
}
