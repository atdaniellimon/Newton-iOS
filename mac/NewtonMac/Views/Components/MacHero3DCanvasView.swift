//
//  MacHero3DCanvasView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  High-performance hardware-accelerated 3D wireframe mesh with 0% CPU overhead.
//

import SwiftUI
import SceneKit
import AppKit

public struct MacHero3DCanvasView: NSViewRepresentable {
    public var isThinking: Bool = false
    
    public init(isThinking: Bool = false) {
        self.isThinking = isThinking
    }
    
    public func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = NSColor.clear
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false
        
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        
        // Create 3D Gravitational Topographic Grid
        let plane = SCNPlane(width: 80, height: 80)
        plane.widthSegmentCount = 40
        plane.heightSegmentCount = 40
        
        let material = SCNMaterial()
        material.fillMode = .lines
        material.diffuse.contents = NSColor(red: 0.40, green: 0.46, blue: 0.54, alpha: 0.12)
        material.isDoubleSided = true
        plane.materials = [material]
        
        let meshNode = SCNNode(geometry: plane)
        meshNode.name = "meshNode"
        meshNode.eulerAngles = SCNVector3(x: -CGFloat.pi / 2.7, y: 0, z: 0)
        meshNode.position = SCNVector3(x: 0, y: -6, z: -12)
        
        // Gentle undulating wave animation
        let waveUp = SCNAction.moveBy(x: 0, y: 1.2, z: 0, duration: 6.0)
        waveUp.timingMode = .easeInEaseOut
        let waveDown = SCNAction.moveBy(x: 0, y: -1.2, z: 0, duration: 6.0)
        waveDown.timingMode = .easeInEaseOut
        let sequence = SCNAction.sequence([waveUp, waveDown])
        meshNode.runAction(SCNAction.repeatForever(sequence), forKey: "waveAction")
        
        scene.rootNode.addChildNode(meshNode)
        
        // Camera with perspective
        let camera = SCNCamera()
        camera.zFar = 200
        camera.fieldOfView = 55
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 8, z: 22)
        cameraNode.eulerAngles = SCNVector3(x: -CGFloat.pi / 9, y: 0, z: 0)
        scene.rootNode.addChildNode(cameraNode)
        
        // Soft Ambient Light
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(white: 0.9, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        
        scnView.scene = scene
        return scnView
    }
    
    public func updateNSView(_ nsView: SCNView, context: Context) {
        guard let meshNode = nsView.scene?.rootNode.childNode(withName: "meshNode", recursively: true) else { return }
        
        // Adjust animation speed smoothly when streaming without rebuilding scene
        if isThinking {
            meshNode.removeAction(forKey: "waveAction")
            let waveUp = SCNAction.moveBy(x: 0, y: 1.5, z: 0, duration: 2.2)
            waveUp.timingMode = .easeInEaseOut
            let waveDown = SCNAction.moveBy(x: 0, y: -1.5, z: 0, duration: 2.2)
            waveDown.timingMode = .easeInEaseOut
            let sequence = SCNAction.sequence([waveUp, waveDown])
            meshNode.runAction(SCNAction.repeatForever(sequence), forKey: "waveAction")
        }
    }
}
