/*
See LICENSE folder for this sample’s licensing information.

Abstract:
UI Actions for the main view controller.
*/

import UIKit
import SceneKit
import AVFoundation

extension ViewController: UIGestureRecognizerDelegate {
    
    enum SegueIdentifier: String {
        case showObjects
    }
    
    // MARK: - Interface Actions
    
    /// Displays the `VirtualObjectSelectionViewController` from the `addObjectButton` or in response to a tap gesture in the `sceneView`.
    @IBAction func showVirtualObjectSelectionViewController() {
        // Ensure adding objects is an available action and we are not loading another object (to avoid concurrent modifications of the scene).
        guard !addObjectButton.isHidden && !virtualObjectLoader.isLoading else { return }
        
        statusViewController.cancelScheduledMessage(for: .contentPlacement)
        performSegue(withIdentifier: SegueIdentifier.showObjects.rawValue, sender: addObjectButton)
    }
    
    @IBAction func placePaperplane() {
        print("placing plane \(primaryObject)")
        guard !addObjectButton.isHidden && !virtualObjectLoader.isLoading else { return }

        statusViewController.cancelScheduledMessage(for: .contentPlacement)

        guard let paperPlane = primaryObject else {
            fatalError("Could not load paper plane")
        }
        
//        loadSelected(virtualObject: object)

        loadSelected(virtualObject: paperPlane)
        
    }
    
    @IBAction func playButtonPressed(_: UIButton) {
        print("pressed")
//        let idleModelName = "paperairplane_Intro-dup"
//        let idleAnimation = loadAnimation(idleModelName)
//        idleAnimation.repeatDuration = 10.0
        if let obj = primaryObject, let introAni = introAnimation, let circleAni = circleAnimation {
//            obj.addAnimation(idleAnimation, forKey: "paperairplane_Intro-dup-1")
            let objWorld = obj.simdWorldTransform.orientation
//            ani.
//            obj.o
            
            for n in obj.childNode(withName: "Armature-001", recursively: true)!.childNodes {
                print("node name \(n.name) \(n)")
            }
            print("before orientation \(obj.objectRotation)")
            if let n = obj.childNode(withName: "Bone", recursively: true) {
                print("before orientation \(n.geometry)")
            }
//            ani.
            
            let introTime = 14.5 // 320.0 / 24.0 = 13.333
            introAni.duration = introTime
//            introAni.blendOutDuration = 0.1
//            circleAni.startDelay = introTime
//            circleAni = 0.1
            let introAniCaa = CAAnimation(scnAnimation: introAni)
            let circleAniCaa = CAAnimation(scnAnimation: circleAni)
            circleAniCaa.speed = 1.2
            chainAnimation(introAniCaa, toAnimation: circleAniCaa, forNode: obj, fadeTime: 1.0)
//            ani.animationEvents = [SCNAnimationEvent. introAni, circleAni]
//            let seq = SCNAction.sequence(introAni., circleAni)
            obj.addAnimation(introAniCaa, forKey: nil)
            playAudio()
//            obj.addAnimation(circleAni, forKey: nil)
            print("after objectRotation \(obj.objectRotation)")
            print("after orientation \(obj.orientation)")
            print("after orientation \(obj.eulerAngles)")
            print("after orientation \(obj.objectRotation)")

            if let n = obj.childNode(withName: "Bone", recursively: true) {
//                n.localRotate(by: SCNQuaternion(1,0,0,0))
                print("after orientation \(n.geometry)")
            }
//            obj.addAnimation(ani, forKey: introAnimationKey)
            print("loaded animation")
        } else {
            print("ooops animation did not load")
            self.statusViewController.showMessage("oops no object to apply animation to")
//            fatalError("oops no object to apply animation to")
        }
//        obj.addAnimation(idleAnimation, forKey: "Idle")
        
//        load
//        if sceneView
    }
    
    func playAudio() {
        print("playing audio")
        if let p = player {
            p.prepareToPlay()
            p.volume = 1.0
            p.play()
        } else {
            print("AVAudioPlayer play")
        }
    }
    
    /// Determines if the tap gesture for presenting the `VirtualObjectSelectionViewController` should be used.
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return virtualObjectLoader.loadedObjects.isEmpty
    }
    
    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        return true
    }
    
    /// - Tag: restartExperience
    func restartExperience() {
        guard isRestartAvailable, !virtualObjectLoader.isLoading else { return }
        isRestartAvailable = false

        statusViewController.cancelAllScheduledMessages()

        virtualObjectLoader.removeAllVirtualObjects()
        addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])

        resetTracking()

        // Disable restart for a while in order to give the session time to restart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.isRestartAvailable = true
            self.upperControlsView.isHidden = false
        }
    }
}

extension ViewController: UIPopoverPresentationControllerDelegate {
    
    // MARK: - UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // All menus should be popovers (even on iPhone).
        if let popoverController = segue.destination.popoverPresentationController, let button = sender as? UIButton {
            popoverController.delegate = self
            popoverController.sourceView = button
            popoverController.sourceRect = button.bounds
        }
        
        guard let identifier = segue.identifier,
              let segueIdentifer = SegueIdentifier(rawValue: identifier),
              segueIdentifer == .showObjects else { return }
        
        let objectsViewController = segue.destination as! VirtualObjectSelectionViewController
        objectsViewController.virtualObjects = VirtualObject.availableObjects
        objectsViewController.delegate = self
        objectsViewController.sceneView = sceneView
        self.objectsViewController = objectsViewController
        
        // Set all rows of currently placed objects to selected.
        for object in virtualObjectLoader.loadedObjects {
            guard let index = VirtualObject.availableObjects.firstIndex(of: object) else { continue }
            objectsViewController.selectedVirtualObjectRows.insert(index)
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        objectsViewController = nil
    }
}
