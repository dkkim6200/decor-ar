//
//  ContentView.swift
//  decor-ar
//
//  Created by Daekun Kim on 2020-02-29.
//  Copyright © 2020 DaekunKim. All rights reserved.
//

import SwiftUI
import RealityKit
import ARKit
import MultipeerConnectivity
import Speech

struct ARContentView : View {
    /// In radians
    @State var furnitureAngle : Float = 0.0
    
    @ObservedObject var arViewModel : ARViewModel = ARViewModel()
    
    var body: some View {
        ZStack {
        #if !targetEnvironment(simulator)
            arViewModel.edgesIgnoringSafeArea(.all).onTapGesture {
//                self.arViewModel.togglePeopleOcclusion()
                self.arViewModel.confirmFurniturePosition()
            }.gesture(
                RotationGesture().onChanged { angle in
                    self.arViewModel.setFurnitureRotation(angle: self.furnitureAngle + Float(angle.radians))
                }.onEnded { angle in
                    self.furnitureAngle += Float(angle.radians)
                    self.furnitureAngle = self.furnitureAngle.truncatingRemainder(dividingBy: 2.0 * Float.pi)
                }
            ).allowsHitTesting(self.arViewModel.placingFurniture)
        #endif
            VStack {
                Spacer()
                
                Text(arViewModel.infoLabel)
                    .font(.body)
                    .fontWeight(.ultraLight)
                    .padding(.bottom, 24.0)
                
                Button(action: {
//                    self.arContentView.arViewContainer.shareSession()
                }) {
                    Text("Share with a friend")
                        .padding(12.0)
                        .background(Color.white)
                        .overlay(
                            Capsule(style: .continuous).stroke(Color.blue, style: StrokeStyle(lineWidth: 5, dash: [10]))
                        )
                }
                Button(action: {
                    self.arViewModel.recordButtonTapped()
                }) {
                    Text("Record")
                        .padding(12.0)
                        .background(Color.white)
                        .overlay(
                            Capsule(style: .continuous).stroke(Color.blue, style: StrokeStyle(lineWidth: 5, dash: [10]))
                        )
                }.disabled(!arViewModel.recordEnabled)
            }
            .padding(.bottom, 6.0)
        }
    }
}

extension ARContentView {
    final class ARViewModel: NSObject, UIViewRepresentable, ObservableObject, ARSessionDelegate, SFSpeechRecognizerDelegate {
        @Published var arView : ARView! = ARView(frame: .zero)
        
        @Published var recordEnabled : Bool = false
        @Published var infoLabel : String = ""
        
        @Published var placingFurniture : Bool = false
        private var currentFurniture : Entity? = nil
        private var currentFurniturePreview : Entity? = nil
        private var currentAnchor : AnchorEntity? = nil
        
        private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        private var recognitionTask: SFSpeechRecognitionTask?
        private let audioEngine = AVAudioEngine()
        
        private var furnitureDict : [String : Entity] = [:]
        
        func makeUIView(context: Context) -> ARView {
            initARView()
            initSpeechRecognizer()
            
            let furnitureScene = try! Experience.loadFurniture()
            furnitureDict[furnitureScene.bookshelf!.name] = furnitureScene.bookshelf
            furnitureDict[furnitureScene.bookshelfPreview!.name] = furnitureScene.bookshelfPreview
            
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
            arView.session.delegate = self
            #endif
        }
        
        func initSpeechRecognizer() {
            speechRecognizer.delegate = self
            
            // Asynchronously make the authorization request.
            SFSpeechRecognizer.requestAuthorization { authStatus in

                // Divert to the app's main thread so that the UI
                // can be updated.
                OperationQueue.main.addOperation {
                    switch authStatus {
                    case .authorized:
                        self.recordEnabled = true
                        self.infoLabel = "Place a furniture."
                        
                    case .denied:
                        self.recordEnabled = false
                        self.infoLabel = "User denied access to speech recognition."
                        
                    case .restricted:
                        self.recordEnabled = false
                        self.infoLabel = "Speech recognition restricted on this device."
                        
                    case .notDetermined:
                        self.recordEnabled = false
                        self.infoLabel = "Speech recognition not yet authorized."
                        
                    default:
                        self.recordEnabled = false
                    }
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            #if !targetEnvironment(simulator) //==============================================================
            switch frame.camera.trackingState {
            case .normal:
                if (placingFurniture) {
                    let results = arView.raycast(from: arView.center,
                                                allowing: .existingPlaneInfinite,
                                                alignment: .horizontal)
                    
                    guard let result = results.first else {
                        return
                    }
                    
                    let resultTransform = Transform(matrix: result.worldTransform)
                    let rotation = currentAnchor!.transform.rotation
                    currentAnchor!.move(to: resultTransform, relativeTo: nil)
                    currentAnchor!.transform.rotation = rotation
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
                
                currentFurniture = furnitureDict["Bookshelf"]
                currentFurniturePreview = furnitureDict["Bookshelf Preview"]
                
                let bookshelfPreviewModel = findEntityWithModelComponent(e: currentFurniturePreview!)
    
                var modelComp : ModelComponent = (bookshelfPreviewModel?.components[ModelComponent])!
                let mat = SimpleMaterial(color: .init(white: 1.0, alpha: 0.3), isMetallic: false)
                modelComp.materials = [mat]
                bookshelfPreviewModel?.components.set(modelComp)
                
                currentAnchor = AnchorEntity(plane: .horizontal)
                currentAnchor?.addChild(currentFurniture!)
                currentAnchor?.addChild(currentFurniturePreview!)
                
                currentFurniture?.isEnabled = false
            }
        }
        
        func confirmFurniturePosition() {
//            furnitureScene.bookshelf!.isEnabled.toggle()
//            furnitureScene.bookshelfPreview!.isEnabled.toggle()
            self.placingFurniture = false
            currentFurniturePreview?.isEnabled = false
            currentFurniture?.isEnabled = true
        }
        
        func setFurnitureRotation(angle: Float) {
            currentAnchor?.transform.rotation = .init(angle: -angle, axis: SIMD3<Float>(0, 1, 0))
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
        
        private func startRecording() throws {
            
            // Cancel the previous task if it's running.
            recognitionTask?.cancel()
            self.recognitionTask = nil
            
            // Configure the audio session for the app.
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = audioEngine.inputNode

            // Create and configure the speech recognition request.
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
            recognitionRequest.shouldReportPartialResults = false
            
            // Keep speech recognition data on device
            if #available(iOS 13, *) {
                recognitionRequest.requiresOnDeviceRecognition = false
            }
            
            // Create a recognition task for the speech recognition session.
            // Keep a reference to the task so that it can be canceled.
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                var isFinal = false
                
                if let result = result {
                    // Update the text view with the results.
                    self.infoLabel = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                    print("Text \(result.bestTranscription.formattedString)")
                    
                    self.addFurniture(called: result.bestTranscription.formattedString)
                }
                
                if error != nil || isFinal {
                    // Stop recognizing speech if there is a problem.
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)

                    self.recognitionRequest = nil
                    self.recognitionTask = nil

                    self.recordEnabled = true
                    self.infoLabel = "Start Recording"
                }
            }

            // Configure the microphone input.
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            // Let the user know to start talking.
            self.infoLabel = "(Go ahead, I'm listening)"
        }
        
        // MARK: SFSpeechRecognizerDelegate
        
        public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
            if available {
                self.recordEnabled = true
                self.infoLabel = "Start Recording"
            } else {
                self.recordEnabled = false
                self.infoLabel = "Recognition Not Available"
            }
        }
        
        // MARK: Interface Builder actions
        
        func recordButtonTapped() {
            if audioEngine.isRunning {
                audioEngine.stop()
                recognitionRequest?.endAudio()
                self.recordEnabled = false
                self.infoLabel = "Stopping"
            } else {
                do {
                    try startRecording()
                    self.infoLabel = "Stop Recording"
                } catch {
                    self.infoLabel = "Recording Not Available"
                }
            }
        }
    }
}

#if DEBUG
struct ARContentView_Previews : PreviewProvider {
    static var previews: some View {
        ARContentView()
    }
}
#endif

