//
//  ARModelView+SpeechRecognizer.swift
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

extension ARViewModel : SFSpeechRecognizerDelegate {    
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
                    self.speechInfoLabel = "Place a furniture."
                    
                case .denied:
                    self.recordEnabled = false
                    self.speechInfoLabel = "User denied access to speech recognition."
                    
                case .restricted:
                    self.recordEnabled = false
                    self.speechInfoLabel = "Speech recognition restricted on this device."
                    
                case .notDetermined:
                    self.recordEnabled = false
                    self.speechInfoLabel = "Speech recognition not yet authorized."
                    
                default:
                    self.recordEnabled = false
                }
            }
        }
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
//                self.speechInfoLabel = result.bestTranscription.formattedString
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
                self.speechInfoLabel = "Start Recording"
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
        self.speechInfoLabel = "(Go ahead, I'm listening)"
    }
    
    // MARK: SFSpeechRecognizerDelegate

    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            self.recordEnabled = true
            self.speechInfoLabel = "Start Recording"
        } else {
            self.recordEnabled = false
            self.speechInfoLabel = "Recognition Not Available"
        }
    }
    
    // MARK: Interface Builder actions
    
    func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            self.recordEnabled = false
            self.speechInfoLabel = "Stopping"
        } else {
            do {
                try startRecording()
                self.speechInfoLabel = "Stop Recording"
            } catch {
                self.speechInfoLabel = "Recording Not Available"
            }
        }
    }
}
