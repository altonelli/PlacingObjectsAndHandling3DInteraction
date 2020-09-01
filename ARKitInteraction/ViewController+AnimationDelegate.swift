//
//  ViewController+AnimationDelegate.swift
//  ARKitInteraction
//
//  Created by Arthur Tonelli on 8/2/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import UIKit
import ARKit


extension ViewController: VirtualObjectAnimationDelegate {
    
//    private func getAnimationAtPath(_ path: URL) -> CAAnimation? {
    private func getAnimationAtPath(_ path: URL) -> SCNAnimation? {
        
        var animation: CAAnimation?

//        guard let scene = SCNScene(named: path.relativeString) else {
//            print("Could not find Scene at \(path.relativeString)")
//            return nil
//        }
////
////        print("scene: \(scene)")
////        print("scene.rootNode: \(scene.rootNode)")
////
//        scene.rootNode.enumerateChildNodes({(child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> () in
//            print("child: \(child)")
//            for key in child.animationKeys {
//                print("key: \(key)")
//            }
//            if let animKey = child.animationKeys.first {
//
//                animation = child.animation(forKey: animKey)!
////                child.anim
//                stop.pointee = true
//            }
//        })
        guard let animScene = SCNSceneSource(url: path, options: nil) else {
            print("Can't find scene")
            return nil
        }
        
        let ani = SCNAnimation(contentsOf: path)
        print("Ani: \(ani)")
        
        print("animScene: \(animScene)")
        
        animScene.entries(passingTest: {(t: Any, id: String, stop: UnsafeMutablePointer<ObjCBool>) -> Bool in
            print("t: \(t)")
            print("id: \(id)")
            print("stop: \(stop)")
            stop.pointee = true
            return true
            })
        
        print(animScene.data)
        print(animScene.scene(options: nil, statusHandler: nil))
        
        for ani in animScene.identifiersOfEntries(withClass: CAAnimation.self) {
            print("CAAnimation \(ani)")
            animation = animScene.entryWithIdentifier(ani, withClass: CAAnimation.self)
        }
        for ani in animScene.identifiersOfEntries(withClass: SCNNode.self) {
            print("SCNNode \(ani)")
        }
        for ani in animScene.identifiersOfEntries(withClass: SCNScene.self) {
            print("SCNScene \(ani)")
        }
        for ani in animScene.identifiersOfEntries(withClass: SCNAnimation.self) {
            print("SCNAnimation \(ani)")
        }
        // SCNMaterial, SCNScene, SCNGeometry, SCNNode, CAAnimation, SCNLight, SCNCamera, SCNSkinner, SCNMorpher, NSImage
//        guard let animation: CAAnimation = animScene.entryWithIdentifier("Idle1", withClass:CAAnimation.self) else {
//            print("heh?")
//            return nil
//        }
        
//        animation = CAAnimation.animationWithSc
        
        print("animation: \(animation)")
        
        
        return ani
    }
    
    
//    func loadAnimation(_ name: String) -> CAAnimation {
    func loadAnimation(_ name: String) -> SCNAnimation {
//        let introAnimation = getAnimationAtPath("Models.scnassets/paperplane/paperairplane-intro.scn")!
//        let circlexAnimation = getAnimationAtPath("Models.scnassets/paperplane/paperairplane-circle.scn")!
//        let path = "Models.scnassets/paperairplane/" + name + ".scn"
        guard let urls = Bundle.main.url(forResource: "Models.scnassets",
                                       withExtension: nil) else {
            fatalError("Could not find url for name \(name)")
        }
        
        let fileEnumerator = FileManager().enumerator(at: urls, includingPropertiesForKeys: [])!

        var finalUrl: URL?
        fileEnumerator.forEach({ element in
            let url = element as! URL

//            print(url.lastPathComponent)
//            if url.pathExtension == "dae" && url.lastPathComponent == name + ".dae" {
            if url.pathExtension == "scn" && url.lastPathComponent == name + ".scn" {

                finalUrl = url
            }
        })
        
        guard let aniUrl = finalUrl, let animation = getAnimationAtPath(aniUrl) else {
            fatalError("Could not load animation \(name): at \(finalUrl)")
        }
        
        return animation
    }
    
    func chainAnimation(_ firstAnimation: CAAnimation, toAnimation secondAnimation: CAAnimation, forNode node: SCNNode, fadeTime: CGFloat) {
//        guard let
//            firstAnim = self.cachedAnimationForKey(firstKey),
//            let secondAnim = self.cachedAnimationForKey(secondKey)
//            else {
//                return
//        }
        
        let chainEventBlock: SCNAnimationEventBlock = {animation, animatedObject, playingBackward in
            node.addAnimation(secondAnimation, forKey: nil)
        }
        
        if firstAnimation.animationEvents == nil || firstAnimation.animationEvents!.count == 0 {
            firstAnimation.animationEvents = [SCNAnimationEvent(keyTime: fadeTime, block: chainEventBlock)]
        } else {
            var pastEvents = firstAnimation.animationEvents
            pastEvents?.append(SCNAnimationEvent(keyTime: fadeTime, block: chainEventBlock))
            firstAnimation.animationEvents = pastEvents
        }
    }
    
    func runAnimationOnVirtualObject() {
        
    }
}
