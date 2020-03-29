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
                Text(arViewModel.collaborationInfoLabel)
                    .font(.body)
                    .fontWeight(.regular)
                    .padding(.top, 24.0)
                
                Spacer()
                
                Text(arViewModel.speechInfoLabel)
                    .font(.body)
                    .fontWeight(.regular)
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

#if DEBUG
struct ARContentView_Previews : PreviewProvider {
    static var previews: some View {
        ARContentView()
    }
}
#endif

