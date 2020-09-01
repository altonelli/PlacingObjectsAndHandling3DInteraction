//
//  AnimationDelegate.swift
//  ARKitInteraction
//
//  Created by Arthur Tonelli on 8/2/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import ARKit


protocol VirtualObjectAnimationDelegate: class {
//    func loadAnimation(_ name: String) -> CAAnimation
    func loadAnimation(_ name: String) -> SCNAnimation
    func runAnimationOnVirtualObject()
}
