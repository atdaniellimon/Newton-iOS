//
//  MacHero3DCanvasView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Renders the undulating kinetic wireframe topographic mesh grid.
//

import SwiftUI
import SceneKit

public struct MacHero3DCanvasView: View {
    public var isThinking: Bool = false
    
    public init(isThinking: Bool = false) {
        self.isThinking = isThinking
    }
    
    public var body: some View {
        SceneView(
            scene: makeMeshScene(),
            options: [.autoenablesDefaultLighting]
        )
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func makeMeshScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        
        let plane = SCNPlane(width: 70, height: 70)
        plane.widthSegmentCount = 44
        plane.heightSegmentCount = 44
        
        let material = SCNMaterial()
        material.fillMode = .lines
        material.diffuse.contents = NSColor(red: 0.35, green: 0.42, blue: 0.52, alpha: 0.16)
        material.isDoubleSided = true
        plane.materials = [material]
        
        let meshNode = SCNNode(geometry: plane)
        meshNode.eulerAngles = SCNVector3(x: -CGFloat.pi / 2.6, y: 0, z: 0)
        meshNode.position = SCNVector3(x: 0, y: -4, z: -10)
        
        // Gentle undulating wave / breathing animation
        let waveUp = SCNAction.moveBy(x: 0, y: 1.5, z: 0, duration: isThinking ? 2.5 : 6.0)
        waveUp.timingMode = .easeInEaseOut
        let waveDown = SCNAction.moveBy(x: 0, y: -1.5, z: 0, duration: isThinking ? 2.5 : 6.0)
        waveDown.timingMode = .easeInEaseOut
        let sequence = SCNAction.sequence([waveUp, waveDown])
        meshNode.runAction(SCNAction.repeatForever(sequence))
        
        scene.rootNode.addChildNode(meshNode)
        
        // Camera
        let camera = SCNCamera()
        camera.zFar = 200
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 10, z: 24)
        cameraNode.eulerAngles = SCNVector3(x: -CGFloat.pi / 8, y: 0, z: 0)
        scene.rootNode.addChildNode(cameraNode)
        
        // Soft Ambient Light
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(white: 0.8, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        
        return scene
    }
}
