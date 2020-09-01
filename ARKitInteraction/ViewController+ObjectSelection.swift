/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Methods on the main view controller for handling virtual object loading and movement
*/

import UIKit
import ARKit

extension ViewController: VirtualObjectSelectionViewControllerDelegate {
    
    /** Adds the specified virtual object to the scene, placed at the world-space position
     estimated by a hit test from the center of the screen.
     - Tag: PlaceVirtualObject */
    func placeVirtualObject(_ virtualObject: VirtualObject) {
        print("placing \(virtualObject.modelName) at \(virtualObject.raycastQuery)")
        
        guard focusSquare.state != .initializing, let query = virtualObject.raycastQuery else {
            self.statusViewController.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
            if let controller = self.objectsViewController {
                self.virtualObjectSelectionViewController(controller, didDeselectObject: virtualObject)
            }
            print("FUCK")
            return
        }
       
        let trackedRaycast = createTrackedRaycastAndSet3DPosition(of: virtualObject, from: query,
                                                                  withInitialResult: virtualObject.mostRecentInitialPlacementResult)
        
        print("ray cast: \(trackedRaycast)")
        
        virtualObject.raycast = trackedRaycast
        virtualObjectInteraction.selectedObject = virtualObject
        virtualObject.isHidden = false
    }
    
    // - Tag: GetTrackedRaycast
    func createTrackedRaycastAndSet3DPosition(of virtualObject: VirtualObject, from query: ARRaycastQuery,
                                              withInitialResult initialResult: ARRaycastResult? = nil) -> ARTrackedRaycast? {
        if let initialResult = initialResult {
            self.setTransform(of: virtualObject, with: initialResult)
        }
        
        return session.trackedRaycast(query) { (results) in
            self.setVirtualObject3DPosition(results, with: virtualObject)
        }
    }
    
    func createRaycastAndUpdate3DPosition(of virtualObject: VirtualObject, from query: ARRaycastQuery) {
        guard let result = session.raycast(query).first else {
            return
        }
        
        if virtualObject.allowedAlignment == .any && self.virtualObjectInteraction.trackedObject == virtualObject {
            
            // If an object that's aligned to a surface is being dragged, then
            // smoothen its orientation to avoid visible jumps, and apply only the translation directly.
            virtualObject.simdWorldPosition = result.worldTransform.translation
            
            let previousOrientation = virtualObject.simdWorldTransform.orientation
            let currentOrientation = result.worldTransform.orientation
            virtualObject.simdWorldOrientation = simd_slerp(previousOrientation, currentOrientation, 0.1)
        } else {
            self.setTransform(of: virtualObject, with: result)
        }
    }
    
    public func degToRadians(degrees:Float) -> Float
    {
        return degrees * Float.pi / 180;
    }
    
    
//    x = cos(yaw)*cos(pitch)
//    y = sin(yaw)*cos(pitch)
//    z = sin(pitch)
    private func getYFrom(eulerAngles angles: SCNVector3) -> SCNVector3 {
        let x = -sin(angles.y) * cos(angles.x)
        let y = sin(angles.x)
        let z = -cos(angles.y) * cos(angles.x)
        let directionVector = SCNVector3(x: x, y: y, z: z)
        print("Getting Direction \(directionVector) from Euler \(angles)")
        return directionVector
    }
    
    private func printEuler(sequence: String = "", withDirection: Bool = false, withPivot: Bool = false) -> SCNAction {
        var suf: String = ""
        if sequence != "" {
            suf = " at " + sequence
        }
        
        return SCNAction.run({node -> () in
                print("printing euler for node...\(node.eulerAngles)" + suf)
                if withDirection {
                    print("printing direction \(self.getYFrom(eulerAngles: node.eulerAngles))" + suf)
                }
                if withPivot {
                    print("printing pivot... \(node.pivot)" + suf)
                }
        })
    }
    
    private func getNormal(firstVector: SCNVector3, secondVector: SCNVector3) -> SCNVector3 {
        let _x = simd_float3(firstVector.x, firstVector.y, firstVector.z)
        let _y = simd_float3(secondVector.x, secondVector.y, secondVector.z)
        let cross = simd_cross(_x, _y)
        return SCNVector3(x: cross[0], y: cross[1], z: cross[2])
    }
    

    
    // - Tag: ProcessRaycastResults
    private func setVirtualObject3DPosition(_ results: [ARRaycastResult], with virtualObject: VirtualObject) {
        print("attempting to set virtual object \(virtualObject) at \(results)")
        
        guard let result = results.first else {
            fatalError("Unexpected case: the update handler is always supposed to return at least one result.")
        }
        
        self.setTransform(of: virtualObject, with: result)
        
        // If the virtual object is not yet in the scene, add it.
        print("parent: \(virtualObject.parent)")
        if virtualObject.parent == nil {
//            let startAxis = virtualObject.coor
            let pivot = virtualObject.pivot
            let startPosition = virtualObject.position
            let startRotation = virtualObject.rotation
            let startOrientation = virtualObject.orientation
            let startEuler = virtualObject.eulerAngles
            let startDirection = getYFrom(eulerAngles: startEuler)
//            virtualObject.ro
            let scale = virtualObject.scale
            let uniformScale = scale.z
            
                        
            print("startPosition: \(startPosition)")
            print("startPivot: \(pivot)")
            print("startRotation: \(startRotation)")
            print("startOrientation: \(startOrientation)")
            print("startEuler: \(startEuler)")
            print("startDirection: \(startDirection)")
            
            
//            let printEuler: (sequence: String = '', withPivot: Boolean = false) -> SCNAction = {
//                    SCNAction.run({node -> () in
//                    print("printing euler for node...\(node.eulerAngles)")
//                    if withPivot {
//                        print("printing pivot... \(node.pivot)")
//                    }
//                })
//            }
            
            let printPosition = SCNAction.run({node -> () in
                print("printing position update \(node.position)")
            })

            
            let delayStart = SCNAction.wait(duration: 1.0)
            let yRot = Float(-1.0)
            let zRot = Float(1.0)
            
            
            
            let openingEuler = SCNVector3(x: startEuler.x, y: startEuler.y + yRot, z: startEuler.z + zRot)
            let openingDirection = getYFrom(eulerAngles: openingEuler)
            
            let openingNormal = getNormal(firstVector: openingDirection, secondVector: startDirection)
            print("Opening Normal: \(openingNormal)")
            
            
//            let startY = SCNAction.rotateBy(x: 0.0, y: CGFloat(yRot), z: 0.0, duration: 0.5)
            let startY = SCNAction.rotate(by: CGFloat(yRot), around: openingNormal, duration: 0.5)
            let startYDirection = getYFrom(eulerAngles: SCNVector3(x: startEuler.x, y: startEuler.y + yRot, z: startEuler.z))
            let startZ = SCNAction.rotate(by: CGFloat(zRot), around: startYDirection, duration: 0.5)
            
            

            

//            let rollAnimationUrl = Bundle.main.url(forResource: "paperairplane-animated-rig-rolls",
//                                                   withExtension: "scn",
//                                                   subdirectory: "Resources/Models.scnassets/paperplane/"
//                )!
            let rollAnimationPath = "Models.scnassets/paperplane/paperairplane-a-2.scn"
//            var animation: CAAnimation?
//
//            do {
//                let scene = try SCNScene(named: rollAnimationPath)!
//                scene.rootNode.enumerateChildNodes({(child: SCNNode, stop: UnsafeMutablePointer<ObjCBool>) -> () in
//                if (child.animationKeys.count > 0) {
//                    animation = child.animation(forKey: child.animationKeys[0])!
//                    stop[0] = true
//                }
//                })
//            } catch {
//                fatalError("Failed to load SCNScene with Roll Animation Load")
//            }
            

            
//            introAnimation.fadeOutDuration = 0.2
//            introAnimation.duration = 355.0 / 30
//
//            let addCircleAnimation = {animation, animatedObject:VirtualObject, _ in
//                animatedObject.addA
//            }
//
//            introAnimation.animationEvents = [SCNAnimationEvent]
//
//            circleAnimation.fadeInDuration = 0.2
//
//
//            SCNAnimation.
//
//            virtualObject.addAnimation(introAnimation, forKey: "Intro")
//            virtualObject.addAnimation(Animation, forKey: "Intro")
//
////            let rollAnimation = loadAnimationFromSceneNamed(path: rollAnimationUrl)
//            virtualObject.addAnimation(animation!, forKey: "Rolls")
//
//            virtualObject.runAction(fullSequence)
//
            
//            if let ani = introAnimation {
//                virtualObject.addAnimation(ani, forKey: introAnimationKey)
//            } else {
//                print("Ooops no animation when setting object")
//            }
            self.sceneView.scene.rootNode.addChildNode(virtualObject)
            
            virtualObject.shouldUpdateAnchor = true
        }
        
        if virtualObject.shouldUpdateAnchor {
            virtualObject.shouldUpdateAnchor = false
            self.updateQueue.async {
                self.sceneView.addOrUpdateAnchor(for: virtualObject)
            }
        }
    }
    
    func setTransform(of virtualObject: VirtualObject, with result: ARRaycastResult) {
        virtualObject.simdWorldTransform = result.worldTransform
//        virtualObject.simdEulerAngles = simd_float3(0,0,0)
    }
    
    func loadSelected(virtualObject object: VirtualObject) {
        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
            
            do {
                let scene = try SCNScene(url: object.referenceURL, options: nil)
                self.sceneView.prepare([scene], completionHandler: { _ in
                    DispatchQueue.main.async {
                        self.hideObjectLoadingUI()
                        self.placeVirtualObject(loadedObject)
                    }
                })
            } catch {
                fatalError("Failed to load SCNScene from object.referenceURL")
            }
            
        })
        displayObjectLoadingUI()
    }

    // MARK: - VirtualObjectSelectionViewControllerDelegate
    // - Tag: PlaceVirtualContent
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didSelectObject object: VirtualObject) {
        loadSelected(virtualObject: object)
//        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
//
//            do {
//                let scene = try SCNScene(url: object.referenceURL, options: nil)
//                self.sceneView.prepare([scene], completionHandler: { _ in
//                    DispatchQueue.main.async {
//                        self.hideObjectLoadingUI()
//                        self.placeVirtualObject(loadedObject)
//                    }
//                })
//            } catch {
//                fatalError("Failed to load SCNScene from object.referenceURL")
//            }
//
//        })
//        displayObjectLoadingUI()
    }
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didDeselectObject object: VirtualObject) {
        guard let objectIndex = virtualObjectLoader.loadedObjects.firstIndex(of: object) else {
            fatalError("Programmer error: Failed to lookup virtual object in scene.")
        }
        virtualObjectLoader.removeVirtualObject(at: objectIndex)
        virtualObjectInteraction.selectedObject = nil
        if let anchor = object.anchor {
            session.remove(anchor: anchor)
        }
    }

    // MARK: Object Loading UI

    func displayObjectLoadingUI() {
        // Show progress indicator.
        spinner.startAnimating()
        
        addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])

        addObjectButton.isEnabled = false
        playButton.isEnabled = false
        playButton.isHidden = true
        isRestartAvailable = false
    }

    func hideObjectLoadingUI() {
        // Hide progress indicator.
        spinner.stopAnimating()

        addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])

        addObjectButton.isEnabled = true
        playButton.isEnabled = true
        playButton.isHidden = false
        isRestartAvailable = true
    }
}
