/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 ARSCNViewDelegate interactions for `ViewController`.
 */

import ARKit
//import Vision
import Accelerate


extension ViewController: ARSCNViewDelegate, ARSessionDelegate {
    
    // MARK: - ARSCNViewDelegate
    
    func imageOrientationToDeviceOrientation(value: UIDeviceOrientation) -> Int32 {
        switch (value) {
        case .portrait:
            return 6
        case .landscapeLeft:
            return 1
        case .landscapeRight:
            return 3
        default:
            return 6
        }
    }
    
    private func currentScreenTransform() -> SCNMatrix4? {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return SCNMatrix4Identity
        case .landscapeRight:
            return SCNMatrix4MakeRotation(.pi, 0, 0, 1)
        case .portrait:
            return SCNMatrix4MakeRotation(.pi / 2, 0, 0, 1)
        case .portraitUpsideDown:
            return SCNMatrix4MakeRotation(-.pi / 2, 0, 0, 1)
        default:
            return nil
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        print(time)
        
        let startTime = DispatchTime.now()
        
        if let bg = sceneView.session.currentFrame?.capturedImage {


            print("******")
            guard let buff = convertPixelBuffer(bg.copyToMetalCompatible()!, conversionPtr: &self.infoYpCbCrToARGB) else {
                print("CRAP")
                return
            }
            
            guard let rotated = rotate90PixelBuffer(buff, factor: 3) else {
                print("could not rotate")
                return
            }
            
            //                print("buff \(buff)")
            //
//            //
//            guard let downsizedBuffer = resizePixelBufferArthur(rotated, width: self.modelWidth, height: self.modelHeight, ioSurface: nil) else {
//                return
//            }
            
            guard let downsizedBuffer = resizePixelBuffer(rotated, cropX: 360, cropY: 0,
            cropWidth: 720,
            cropHeight: 1920,
            scaleWidth: self.modelWidth, scaleHeight: self.modelHeight) else {
                   return
               }
            print("wiiiiidth: \(CVPixelBufferGetWidth(downsizedBuffer))")
            print("heeeiight: \(CVPixelBufferGetHeight(downsizedBuffer))")
            //
            print(CVPixelBufferGetPixelFormatName(pixelBuffer: buff))
            
            if let res = self.modelHandler.runModel(onFrame: downsizedBuffer) {
                print("ran model")
//                print(res.buffer)
//                print(CVPixelBufferGetPixelFormatName(pixelBuffer: res.buffer))
//
                let context = CIContext()
//                let filter:CIFilter = CIFilter(name: "CIColorMonochrome")!
//
//                let image:CIImage = CIImage(cvPixelBuffer: bg, options: nil)
//
//                let cgImage:CGImage = context.createCGImage(image, from: image.extent)!
//                let uiImage:UIImage = UIImage.init(cgImage: cgImage)
//                let resultImage = CIImage(image: uiImage)
//    //                ?.oriented(forExifOrientation: imageOrientationToDeviceOrientation(value: UIDevice.current.orientation))
//
//                filter.setValue(resultImage, forKey: kCIInputImageKey)
//
//                let result = filter.outputImage!
//
//                sceneView.scene.background.contents = context.createCGImage(result, from: result.extent)

//                sceneView.scene.background.contents = CIImage(cvPixelBuffer: res.buffer, options: nil)
                
                let bgi = CIImage(cvPixelBuffer: res.buffer, options: nil)
                print(bgi.extent)
                // 1125.0, 2436.0

                
//                sceneView.scene.background.contents = context.createCGImage(bgi, from: CGRect(origin: CGPoint(x: 0,y: 0), size: CGSize(width: 1125.0, height: 2436.0)))
//                sceneView.scene.background.contents = context.createCGImage(bgi, from: CGRect(origin: CGPoint(x: 100,y: 0), size: CGSize(width: 1440.0, height: 1920.0)))
                sceneView.scene.background.contents =
                    context.createCGImage(bgi, from: bgi.extent)
//                sceneView.scene.background.
            } else {
                sceneView.scene.background.contents = bg
                
            }
            
            if let transform = currentScreenTransform() {
                
                sceneView.scene.background.contentsTransform = SCNMatrix4Identity //
            }
            

            
            let endTime = DispatchTime.now()
            
            print("convert duration: \(startTime.distance(to: endTime))")
            
            //            }
            

            //            if let transform = currentScreenTransform() {
            //                sceneView.scene.background.contentsTransform = transform
            //            }
            
        }
        
        let isAnyObjectInView = virtualObjectLoader.loadedObjects.contains { object in
            return sceneView.isNode(object, insideFrustumOf: sceneView.pointOfView!)
        }
        
        DispatchQueue.main.async {
            self.updateFocusSquare(isObjectVisible: isAnyObjectInView)
            
            // If the object selection menu is open, update availability of items
            if self.objectsViewController?.viewIfLoaded?.window != nil {
                self.objectsViewController?.updateObjectAvailability()
            }
            
            self.updatePrimaryObjectAvailability()
            
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.statusViewController.cancelScheduledMessage(for: .planeEstimation)
            self.statusViewController.showMessage("SURFACE DETECTED")
            if self.virtualObjectLoader.loadedObjects.isEmpty {
                self.statusViewController.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        updateQueue.async {
            if let objectAtAnchor = self.virtualObjectLoader.loadedObjects.first(where: { $0.anchor == anchor }) {
                objectAtAnchor.simdPosition = anchor.transform.translation
                objectAtAnchor.anchor = anchor
            }
        }
    }
    
    /// - Tag: ShowVirtualContent
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        statusViewController.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        switch camera.trackingState {
        case .notAvailable, .limited:
            statusViewController.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            statusViewController.cancelScheduledMessage(for: .trackingStateEscalation)
            showVirtualContent()
        }
    }
    
    func showVirtualContent() {
        virtualObjectLoader.loadedObjects.forEach { $0.isHidden = false }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Hide content before going into the background.
        hideVirtualContent()
    }
    
    /// - Tag: HideVirtualContent
    func hideVirtualContent() {
        virtualObjectLoader.loadedObjects.forEach { $0.isHidden = true }
    }
    
    /*
     Allow the session to attempt to resume after an interruption.
     This process may not succeed, so the app must be prepared
     to reset the session if the relocalizing status continues
     for a long time -- see `escalateFeedback` in `StatusViewController`.
     */
    /// - Tag: Relocalization
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}
