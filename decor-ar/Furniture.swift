//
//  Furniture.swift
//  decor-ar
//
//  Created by Daekun Kim on 2020-03-28.
//  Copyright © 2020 DaekunKim. All rights reserved.
//

import RealityKit
import ARKit

struct Furniture {
    let furniture : Entity?
    let furniturePreview : Entity?
    
    init() {
        furniture = nil
        furniturePreview = nil
    }
    
    init(furniture : Entity, furniturePreview : Entity) {
        self.furniture = furniture.clone(recursive: true)
        self.furniturePreview = furniturePreview.clone(recursive: true)
    }
}
