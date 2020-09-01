//
//  ObjectPlacementDelegate.swift
//  ARKitInteraction
//
//  Created by Arthur Tonelli on 8/4/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation


protocol ObjectPlacementDelegate {
    var lastObjectAvailabilityUpdateTimestamp: TimeInterval? { get set }
    func updatePrimaryObjectAvailability()
}

extension ViewController: ObjectPlacementDelegate {
    
    func updatePrimaryObjectAvailability() {
        guard let sceneView = sceneView else { return }
        
        // Update object availability only if the last update was at least half a second ago.
        if let lastUpdateTimestamp = lastObjectAvailabilityUpdateTimestamp,
            let timestamp = sceneView.session.currentFrame?.timestamp,
            timestamp - lastUpdateTimestamp < 0.5 {
            return
        } else {
            lastObjectAvailabilityUpdateTimestamp = sceneView.session.currentFrame?.timestamp
        }
                
        if let object = primaryObject {
            if let query = sceneView.getRaycastQuery(for: object.allowedAlignment),
                let result = sceneView.castRay(for: query).first {
            // Enable object if item can be placed at the current location
                object.mostRecentInitialPlacementResult = result
                object.raycastQuery = query
//                print("updated placement to \(result)")
            } else {
                object.mostRecentInitialPlacementResult = nil
                object.raycastQuery = nil
            }
        }
    }
}
