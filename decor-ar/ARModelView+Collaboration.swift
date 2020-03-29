//
//  ARModelView+Collaboration.swift
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

#if !targetEnvironment(simulator)
extension ARViewModel {
    func initCollaborationSession() {
        // Use key-value observation to monitor your ARSession's identifier.
        sessionIDObservation = observe(\.arView.session.identifier, options: [.new]) { object, change in
            print("SessionID changed to: \(change.newValue!)")
            // Tell all other peers about your ARSession's changed ID, so
            // that they can keep track of which ARAnchors are yours.
            guard let multipeerSession = self.multipeerSession else { return }
            self.sendARSessionIDTo(peers: multipeerSession.connectedPeers)
        }
        
        // Start looking for other players via MultiPeerConnectivity.
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData, peerJoinedHandler:
                                            peerJoined, peerLeftHandler: peerLeft, peerDiscoveredHandler: peerDiscovered)
        
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        collaborationInfoLabel = "Tap the screen to place cubes.\nInvite others to launch this app to join you."
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let participantAnchor = anchor as? ARParticipantAnchor {
                collaborationInfoLabel = "Established joint experience with a peer."
                // ...
                let anchorEntity = AnchorEntity(anchor: participantAnchor)
                
                let coordinateSystem = MeshResource.generateCoordinateSystemAxes()
                anchorEntity.addChild(coordinateSystem)
                
                let color = participantAnchor.sessionIdentifier?.toRandomColor() ?? .white
                let coloredSphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.03),
                                                materials: [SimpleMaterial(color: color, isMetallic: true)])
                anchorEntity.addChild(coloredSphere)
                
                arView.scene.addAnchor(anchorEntity)
            }
            else if anchor.sessionIdentifier != arView.session.identifier {
                if (anchor.name != nil && !anchor.name!.isEmpty) {
                    print(anchor.name!)
                }
                
                guard let furnitureName = anchor.name?.components(separatedBy: " ").first else {
                    continue;
                }
                
                let anchorEntity = AnchorEntity(anchor: anchor)
                anchorEntity.name = anchor.name!
                
                if furnitureName == "Bookshelf" {
                    anchorEntity.addChild(furnitureDict["Bookshelf"]!.clone(recursive: true))
                }
                else if furnitureName == "Bookshelf-Preview" {
                    anchorEntity.addChild(furnitureDict["Bookshelf-Preview"]!.clone(recursive: true))
                }
                
                arView.scene.addAnchor(anchorEntity)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor.sessionIdentifier != arView.session.identifier {
                guard let anchorName = anchor.name else {
                    continue;
                }

                let anchorEntity = arView.scene.findEntity(named: anchorName)
                guard let hasAnchoring = anchorEntity as? HasAnchoring else {
                    continue;
                }
                arView.scene.removeAnchor(hasAnchoring)
            }
        }
    }
    
    /// - Tag: DidOutputCollaborationData
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
        guard let multipeerSession = multipeerSession else { return }
        if !multipeerSession.connectedPeers.isEmpty {
            guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
            else { fatalError("Unexpectedly failed to encode collaboration data.") }
            // Use reliable mode if the data is critical, and unreliable mode if the data is optional.
            let dataIsCritical = data.priority == .critical
            multipeerSession.sendToAllPeers(encodedData, reliably: dataIsCritical)
        } else {
            print("Deferred sending collaboration to later because there are no peers.")
        }
    }

    func receivedData(_ data: Data, from peer: MCPeerID) {
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) {
            arView.session.update(with: collaborationData)
            return
        }
        // ...
        let sessionIDCommandString = "SessionID:"
        if let commandString = String(data: data, encoding: .utf8), commandString.starts(with: sessionIDCommandString) {
            let newSessionID = String(commandString[commandString.index(commandString.startIndex,
                                                                     offsetBy: sessionIDCommandString.count)...])
            // If this peer was using a different session ID before, remove all its associated anchors.
            // This will remove the old participant anchor and its geometry from the scene.
            if let oldSessionID = peerSessionIDs[peer] {
                removeAllAnchorsOriginatingFromARSessionWithID(oldSessionID)
            }
            
            peerSessionIDs[peer] = newSessionID
        }
    }
    
    func peerDiscovered(_ peer: MCPeerID) -> Bool {
        guard let multipeerSession = multipeerSession else { return false }
        
        collaborationInfoLabel = "Someone wants to join"
        
        if multipeerSession.connectedPeers.count > 3 {
            // Do not accept more than four users in the experience.
            collaborationInfoLabel = "A fifth peer wants to join the experience.\nThis app is limited to four users."
            return false
        } else {
            return true
        }
    }
    /// - Tag: PeerJoined
    func peerJoined(_ peer: MCPeerID) {
        collaborationInfoLabel = """
            A peer wants to join the experience.
            Hold the phones next to each other.
            """
        // Provide your session ID to the new user so they can keep track of your anchors.
        sendARSessionIDTo(peers: [peer])
    }
        
    func peerLeft(_ peer: MCPeerID) {
        collaborationInfoLabel = "A peer \(peer.displayName) has left the shared experience."
        
        // Remove all ARAnchors associated with the peer that just left the experience.
        if let sessionID = peerSessionIDs[peer] {
            removeAllAnchorsOriginatingFromARSessionWithID(sessionID)
            peerSessionIDs.removeValue(forKey: peer)
        }
    }
    
    private func removeAllAnchorsOriginatingFromARSessionWithID(_ identifier: String) {
        guard let frame = arView.session.currentFrame else { return }
        for anchor in frame.anchors {
            guard let anchorSessionID = anchor.sessionIdentifier else { continue }
            if anchorSessionID.uuidString == identifier {
                arView.session.remove(anchor: anchor)
            }
        }
    }
    
    private func sendARSessionIDTo(peers: [MCPeerID]) {
        guard let multipeerSession = multipeerSession else { return }
        let idString = arView.session.identifier.uuidString
        let command = "SessionID:" + idString
        if let commandData = command.data(using: .utf8) {
            multipeerSession.sendToPeers(commandData, reliably: true, peers: peers)
        }
    }
}
#endif
