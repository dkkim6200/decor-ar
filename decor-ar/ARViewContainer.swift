//
//  ARViewContainer.swift
//  decor-ar
//
//  Created by Daekun Kim on 2020-03-26.
//  Copyright © 2020 DaekunKim. All rights reserved.
//

import SwiftUI
import RealityKit
import ARKit
import MultipeerConnectivity

final class ARViewContainer: NSObject, UIViewRepresentable, ARSessionDelegate {
    var arView : ARView!
    
    private var furnitureScene : Experience.Furniture
    private var pointerScene : Experience.Pointer
    private var isFurniturePreview : Bool = true
    
    private var furnitureAnchor : AnchorEntity {
        get {
            return furnitureScene.children.first as! AnchorEntity
        }
    }
    
    // MARK: - View Life Cycle
    var multipeerSession: MultipeerSession!
    
    override init() {
        arView = ARView(frame: .zero)
        pointerScene = try! Experience.loadPointer()
        furnitureScene = try! Experience.loadFurniture()
    }
    
    func makeUIView(context: Context) -> ARView {
        // Load the "Box" scene from the "Experience" Reality File
        // Add the anchors to the scene
        furnitureScene.bookshelf?.isEnabled = false
        let bookshelfPreviewModel = findEntityWithModelComponent(e: furnitureScene.bookshelfPreview!)
        
        var modelComp : ModelComponent = (bookshelfPreviewModel?.components[ModelComponent])!
        let mat = SimpleMaterial(color: .init(white: 1.0, alpha: 0.3), isMetallic: false)
        modelComp.materials = [mat]
        bookshelfPreviewModel?.components.set(modelComp)
        
        arView.scene.anchors.append(pointerScene)
        arView.scene.anchors.append(furnitureScene)
        furnitureAnchor.name = "Furniture Anchor"
        furnitureScene.name = "Furniture Scene"
        
        #if !targetEnvironment(simulator)
        arView.session.delegate = self
        #endif
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        #if !targetEnvironment(simulator) //==============================================================
        switch frame.camera.trackingState {
        case .normal:
            if (isFurniturePreview) {
                let results = arView.raycast(from: arView.center,
                                            allowing: .existingPlaneInfinite,
                                            alignment: .horizontal)
                
                guard let result = results.first else {
                    return
                }
                
                let resultTransform = Transform(matrix: result.worldTransform)
                let rotation = furnitureAnchor.transform.rotation
                furnitureAnchor.move(to: resultTransform, relativeTo: nil)
                furnitureAnchor.transform.rotation = rotation
            }
            
        case .notAvailable:
            return
        case .limited(_):
            return
        }
        #endif
    }
    
    func toggleFurnitures() {
        furnitureScene.bookshelf!.isEnabled.toggle()
        furnitureScene.bookshelfPreview!.isEnabled.toggle()
        self.isFurniturePreview.toggle()
    }
    
    func setFurnitureRotation(angle: Float) {
        if (isFurniturePreview) {
            furnitureAnchor.transform.rotation = .init(angle: -angle, axis: SIMD3<Float>(0, 1, 0))
        }
    }
    
    func togglePeopleOcclusion() {
        #if !targetEnvironment(simulator)
        guard let config = arView.session.configuration as? ARWorldTrackingConfiguration else {
            fatalError("Unexpectedly failed to get the configuration.")
        }
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else {
//            fatalError("People occlusion is not supported on this device.")
            return
        }
        switch config.frameSemantics {
        case [.personSegmentationWithDepth]:
            config.frameSemantics.remove(.personSegmentationWithDepth)
        default:
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        arView.session.run(config)
        #endif
    }
    
    private func findEntityWithModelComponent(e : Entity, recursiveSearchLimit : Int = 10) -> Entity? {
        var curEntity : Entity = e
        
        var searchLimitCounter : Int = 0
        while (searchLimitCounter < recursiveSearchLimit && curEntity.components[ModelComponent] == nil) {
            curEntity = curEntity.children[0]
            searchLimitCounter += 1
        }
        
        return searchLimitCounter >= recursiveSearchLimit ? nil : curEntity
    }
}
