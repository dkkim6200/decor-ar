//
//  ARModelView.swift
//  decor-ar
//
//  Created by Daekun Kim on 2020-03-28.
//  Copyright © 2020 DaekunKim. All rights reserved.
//

import SwiftUI
import RealityKit
import ARKit
import MultipeerConnectivity
import Speech

final class ARViewModel: NSObject, UIViewRepresentable, ObservableObject, ARSessionDelegate {
    @Published @objc dynamic var arView : ARView! = ARView(frame: .zero)
    private var configuration : ARWorldTrackingConfiguration?
    
    @Published var recordEnabled : Bool = false
    @Published var speechInfoLabel : String = ""
    @Published var transcriptionLabel : String = ""
    @Published var collaborationInfoLabel : String = ""
    
    @Published var placingFurniture : Bool = false
    internal var furnitureDict : [String : Entity] = [:]
    private var currentFurnitureName : String = ""
    private var currentFurniture : Entity? = nil
    private var currentFurniturePreview : Entity? = nil
    internal var currentARAnchor : ARAnchor? = nil
    private var currentAnchor : AnchorEntity? = nil
    
    internal let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    internal var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    internal var recognitionTask: SFSpeechRecognitionTask?
    internal let audioEngine = AVAudioEngine()
    
    private var lastAnchorUpdate : TimeInterval = NSDate().timeIntervalSince1970
    
    var multipeerSession: MultipeerSession?
    // A dictionary to map MultiPeer IDs to ARSession ID's.
    // This is useful for keeping track of which peer created which ARAnchors.
    var peerSessionIDs = [MCPeerID: String]()
    var sessionIDObservation: NSKeyValueObservation?
    
    func makeUIView(context: Context) -> ARView {
        initARView()
        initSpeechRecognizer()
        initCollaborationSession()
        
        let furnitureScene = try! Experience.loadFurniture()
        furnitureDict[furnitureScene.bookshelf!.name] = furnitureScene.bookshelf
        furnitureDict[furnitureScene.bookshelfPreview!.name] = furnitureScene.bookshelfPreview
        
        let bookshelfPreviewModel = findEntityWithModelComponent(e: furnitureScene.bookshelfPreview!)

        var modelComp : ModelComponent = (bookshelfPreviewModel?.components[ModelComponent])!
        let mat = SimpleMaterial(color: .init(white: 1.0, alpha: 0.3), isMetallic: false)
        modelComp.materials = [mat]
        bookshelfPreviewModel?.components.set(modelComp)
        
        for (i, j) in furnitureDict {
            print("\(i) : \(j)")
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
    }
    
    func initARView() {
        // Load the "Box" scene from the "Experience" Reality File
        // Add the anchors to the scene
//            furnitureScene.bookshelf?.isEnabled = false
//            let bookshelfPreviewModel = findEntityWithModelComponent(e: furnitureScene.bookshelfPreview!)
//
//            var modelComp : ModelComponent = (bookshelfPreviewModel?.components[ModelComponent])!
//            let mat = SimpleMaterial(color: .init(white: 1.0, alpha: 0.3), isMetallic: false)
//            modelComp.materials = [mat]
//            bookshelfPreviewModel?.components.set(modelComp)
//
//            arView.scene.anchors.append(pointerScene)
//            arView.scene.anchors.append(furnitureScene)
        
        #if !targetEnvironment(simulator)
        arView.automaticallyConfigureSession = false
        
        configuration = ARWorldTrackingConfiguration()

        // Enable a collaborative session.
        configuration?.isCollaborationEnabled = true
        
        // Enable realistic reflections.
        configuration?.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration?.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        arView.session.delegate = self
        
        // Begin the session.
        arView.session.run(configuration!)
        #endif
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        #if !targetEnvironment(simulator) //==============================================================
        switch frame.camera.trackingState {
        case .normal:
            if (placingFurniture) {
                let results = arView.raycast(from: arView.center,
                                             allowing: .estimatedPlane,
                                            alignment: .horizontal)
                
                guard let result = results.first else {
                    return
                }
                
                let newAnchor = AnchorEntity()
                newAnchor.addChild(currentFurniture!)
                newAnchor.addChild(currentFurniturePreview!)
                
                let transform = Transform(matrix: result.worldTransform)
                newAnchor.move(to: transform, relativeTo: nil)
                
                if (currentAnchor != nil) {
                    newAnchor.transform.rotation = currentAnchor?.transform.rotation as! simd_quatf
//                        newAnchor.setOrientation((currentAnchor?.transform.rotation)!, relativeTo: nil)
                    arView.scene.removeAnchor(currentAnchor as! HasAnchoring)
                }
                
                arView.scene.addAnchor(newAnchor)
                currentAnchor = newAnchor
                
                let currentTime = NSDate().timeIntervalSince1970
                
                if (currentTime - lastAnchorUpdate > 0.5) {
                    lastAnchorUpdate = currentTime
                    let newARAnchor = ARAnchor(name: currentFurnitureName + "-Preview " + String(NSDate().timeIntervalSince1970), transform: newAnchor.transform.matrix)
                    if (currentARAnchor != nil) {
                        arView.session.remove(anchor: currentARAnchor!)
                    }
                    arView.session.add(anchor: newARAnchor)
                    currentARAnchor = newARAnchor
                }
            }
            
        case .notAvailable:
            return
        case .limited(_):
            return
        }
        #endif
    }
    
    func addFurniture(called name_: String) {
        let name = name_.lowercased()
        
        if (name == "bookshelf") {
            placingFurniture = true
            
            currentFurnitureName = "Bookshelf"
            currentFurniture = furnitureDict["Bookshelf"]?.clone(recursive: true)
            currentFurniturePreview = furnitureDict["Bookshelf-Preview"]?.clone(recursive: true)
            
            currentFurniture?.isEnabled = false
            
//                currentAnchor = AnchorEntity(plane: .horizontal)
//                currentAnchor?.addChild(currentFurniture!)
//                currentAnchor?.addChild(currentFurniturePreview!)
        }
    }
    
    func confirmFurniturePosition() {
//            furnitureScene.bookshelf!.isEnabled.toggle()
//            furnitureScene.bookshelfPreview!.isEnabled.toggle()
        self.placingFurniture = false
        
        let newARAnchor = ARAnchor(name: currentFurnitureName + " " + String(NSDate().timeIntervalSince1970), transform: currentAnchor!.transformMatrix(relativeTo: nil))
        if (currentARAnchor != nil) {
            arView.session.remove(anchor: currentARAnchor!)
        }
        arView.session.add(anchor: newARAnchor)
        
        currentFurniturePreview?.isEnabled = false
        currentFurniture?.isEnabled = true
        currentAnchor = nil
        currentARAnchor = nil
        currentFurnitureName = ""
    }
    
    func setFurnitureRotation(angle: Float) {
        currentAnchor?.transform.rotation = .init(angle: -angle, axis: SIMD3<Float>(0, 1, 0))
    }
    
    @available(*, deprecated)
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
