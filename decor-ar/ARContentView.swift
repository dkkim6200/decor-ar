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

struct ARContentView : View {
    var arViewContainer : ARViewContainer
    var arView : ARView {
        get {
            return arViewContainer.arView
        }
    }
    
    /// In radians
    @State var furnitureAngle : Float = 0.0
    
    init() {
        arViewContainer = ARViewContainer()
    }
    
    var body: some View {
        let rotationGesture = RotationGesture().onChanged { angle in
            self.arViewContainer.setFurnitureRotation(angle: self.furnitureAngle + Float(angle.radians))
        }.onEnded { angle in
            self.furnitureAngle += Float(angle.radians)
            self.furnitureAngle = self.furnitureAngle.truncatingRemainder(dividingBy: 2.0 * Float.pi)
        }
        
        return arViewContainer.edgesIgnoringSafeArea(.all).onTapGesture {
            self.arViewContainer.togglePeopleOcclusion()
            self.arViewContainer.toggleFurnitures()
        }.gesture(rotationGesture)
    }
}

#if DEBUG
struct ARContentView_Previews : PreviewProvider {
    static var previews: some View {
        ARContentView()
    }
}
#endif

