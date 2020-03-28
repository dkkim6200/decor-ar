//
//  AppContentView.swift
//  decor-ar
//
//  Created by Daekun Kim on 2020-03-27.
//  Copyright © 2020 DaekunKim. All rights reserved.
//

import SwiftUI

struct AppContentView: View {
    var arContentView : ARContentView = ARContentView()
    
    var body: some View {
        ZStack {
        #if !targetEnvironment(simulator)
            arContentView
        #endif
            VStack {
                Spacer()
                
                Text("Place the furniture")
                    .font(.title)
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
            }
            .padding(.bottom, 6.0)
        }
    }
}

struct AppContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppContentView()
    }
}
