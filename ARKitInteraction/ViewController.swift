/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import AVFoundation
import Accelerate

class ViewController: UIViewController {
    
    // MARK: IBOutlets
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    // Add ojbect used to pull up a selector menu in `showVirtualObjectSelectionViewController`, now will place plane in `placePaperplane`
    @IBOutlet weak var addObjectButton: UIButton!
    
    @IBOutlet weak var playButton: UIButton!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var upperControlsView: UIView!
    
    let metalQueue = DispatchQueue(label: "MetalQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    var mostRecent: CVPixelBuffer?
    let modelHandler: ModelDataHandler = ModelDataHandler()!
    lazy var previewHeight = Int(1900)
    lazy var previewWidth = Int(1128)
    lazy var modelHeight: Int = modelHandler.sketchInputHeight
    lazy var modelWidth: Int = modelHandler.sketchInputWidth
    
    var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
    var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 16,
                                             CbCr_bias: 128,
                                             YpRangeMax: 235,
                                             CbCrRangeMax: 240,
                                             YpMax: 235,
                                             YpMin: 16,
                                             CbCrMax: 240,
                                             CbCrMin: 16)
    
//    let metalHandler = MetalStuff()
    
    // MARK: - UI Elements
    
    var primaryObject: VirtualObject? = .primaryObject
    
    var introAnimation:  SCNAnimation? // CAAnimation?
    var circleAnimation:  SCNAnimation? // CAAnimation?
    let introAnimationKey = "paperairplane_Intro-dup-1"
    
    // for ObjectPlacementDelegate
    var lastObjectAvailabilityUpdateTimestamp: TimeInterval?
    
    let coachingOverlay = ARCoachingOverlayView()
    
    var focusSquare = FocusSquare()
    
    var player: AVAudioPlayer?
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    /// The view controller that displays the virtual object selection menu.
    var objectsViewController: VirtualObjectSelectionViewController?
    
    // MARK: - ARKit Configuration Properties
    
    /// A type which manages gesture manipulation of virtual content in the scene.
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: sceneView, viewController: self)
    
    /// Coordinates the loading and unloading of reference nodes for virtual objects.
    let virtualObjectLoader = VirtualObjectLoader()
    
    /// Marks if the AR experience is available for restart.
    var isRestartAvailable = true
    
    /// A serial queue used to coordinate adding or removing nodes from the scene.
    let updateQueue = DispatchQueue(label: "com.example.apple-samplecode.arkitexample.serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    var currentEuler: SCNVector3?
    var currentPosition: SCNVector3?
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        sceneView.autoenablesDefaultLighting = true
        sceneView.session.delegate = self
        
        // Set up coaching overlay.
        setupCoachingOverlay()

        // Set up scene content.
        sceneView.scene.rootNode.addChildNode(focusSquare)

        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showVirtualObjectSelectionViewController))
        let tapGesturePlane = UITapGestureRecognizer(target: self, action: #selector(placePaperplane))
        // Set the delegate to ensure this gesture is only used when there are no virtual objects in the scene.
        tapGesture.delegate = self
        tapGesturePlane.delegate = self
        sceneView.addGestureRecognizer(tapGesture)
        sceneView.addGestureRecognizer(tapGesturePlane)
        
        var idleModelName = "paperairplane-idle-converted"
        let introModelName = "paperairplane_Intro-dup-zy-global"
        let circleModelName = "paperairplane_Circle"
//        let introModelName = "paperairplane-intro"
        introAnimation = loadAnimation(introModelName)
        circleAnimation = loadAnimation(circleModelName)
        let fileURL = Bundle.main.path(forResource: "paperman-trimmed", ofType: "mp3")
        do {
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileURL!))
        } catch let error as NSError {
            print(error.localizedDescription)
        } catch {
            print("AVAudioPlayer init failed")
        }
        
        var error = kvImageNoError
            
        error = vImageConvert_YpCbCrToARGB_GenerateConversion(
                kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!,
                &pixelRange,
                &infoYpCbCrToARGB,
                kvImage422CbYpCrYp8,
                kvImageARGB8888,
                vImage_Flags(kvImageNoFlags))
            
        guard error == kvImageNoError else {
            print("info error : \(error)")
            fatalError("Failed to get image converter")
        }
    }
    
    func configureYpCbCrToARGBInfo() -> vImage_Error {
        let error = vImageConvert_YpCbCrToARGB_GenerateConversion(
            kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!,
            &pixelRange,
            &infoYpCbCrToARGB,
            kvImage422CbYpCrYp8,
            kvImageARGB8888,
            vImage_Flags(kvImageNoFlags))

        return error
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        // Start the `ARSession`.
        resetTracking()
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        session.pause()
    }

    // MARK: - Session management
    
    /// Creates a new AR configuration to run on the `session`.
    func resetTracking() {
        virtualObjectInteraction.selectedObject = nil
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
//        let videoFormat = ARConfiguration.VideoFormat
//        videoFormat.framesPerSecond = 20
//        configuration.videoFormat = videoFormat
        if #available(iOS 12.0, *) {
            configuration.environmentTexturing = .automatic
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        sceneView.preferredFramesPerSecond = 30

        statusViewController.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .planeEstimation)
    }

    // MARK: - Focus Square

    func updateFocusSquare(isObjectVisible: Bool) {
        if isObjectVisible || coachingOverlay.isActive {
            focusSquare.hide()
        } else {
            focusSquare.unhide()
            statusViewController.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
        }
        
        // Perform ray casting only when ARKit tracking is in a good state.
        if let camera = session.currentFrame?.camera, case .normal = camera.trackingState,
            let query = sceneView.getRaycastQuery(),
            let result = sceneView.castRay(for: query).first {
            
            updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(raycastResult: result, camera: camera)
            }
            if !coachingOverlay.isActive {
                addObjectButton.isHidden = false
                playButton.isHidden = false
            }
            statusViewController.cancelScheduledMessage(for: .focusSquare)
        } else {
            updateQueue.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
            }
            addObjectButton.isHidden = true
            playButton.isHidden = true
            objectsViewController?.dismiss(animated: false, completion: nil)
        }
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Blur the background.
        blurView.isHidden = false
        
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.blurView.isHidden = true
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }

}
