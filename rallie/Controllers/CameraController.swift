// MARK: - CameraController.swift

import Foundation
import AVFoundation
import UIKit
import Vision
import Combine
import SwiftUI
import CoreGraphics

class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // Singleton instance for shared access
    static let shared = CameraController()
    
    private let session = AVCaptureSession()
    public var previewLayer: AVCaptureVideoPreviewLayer?
    private var output: AVCaptureVideoDataOutput?
    private var lastLogTime: Date? = nil
    
    // For limiting log frequency
    private var lastHomographyWarningTime: Date? = nil
    private var lastFootPositionWarningTime: Date? = nil

    // MARK: - Vision
    private(set) var overlayView = BoundingBoxOverlayView()
        
    private let objectDetector = ObjectDetector()
    private let playerDetector = PlayerDetector()
    private let actionClassifier = ActionClassifier()
        
    var detectedObjects: [DetectedObject] = [] {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayView.boxes = self.detectedObjects
            }
        }
    }

    // MARK: - Outputs
    @Published var projectedCourtLines: [LineSegment] = []
    @Published var homographyMatrix: [NSNumber]? = nil
    @Published var projectedPlayerPosition: CGPoint? = nil
    @Published var playerSpeed: Double = 0.0
    @Published var isTappingEnabled = true
    
    // Action Classifier outputs
    @Published var currentAction: String = "Unknown"
    @Published var actionConfidence: Float = 0.0
    @Published var predictions: [(startFrame: Int, endFrame: Int, label: String, confidence: Float)] = []
    
    // Publishers
    let actionPublisher = PassthroughSubject<(String, Float), Never>()
    let playerPositionPublisher = PassthroughSubject<CGPoint, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Kalman filter for smoothing player position
    private var playerPositionFilter: KalmanFilter?
    
    // Frame counter for action classification
    private var frameCounter: Int = 0
    
    // MARK: - Calibration Points
    @Published var calibrationPoints: [CGPoint] = []
    @Published var userTappedPoints: [CGPoint] = []
    @Published var isCalibrationMode = false
    @Published var calibrationStep = 0
    @Published var calibrationInstructions = "Tap the top-left corner (net, left sideline)"
    
    // Debug flag to help troubleshoot calibration issues
    private var debugCalibration = true

    // Track if calibration has been performed before
    @Published var hasCalibrationBeenPerformedBefore = false
    @Published var showRecalibrationPrompt = false
    
    // UserDefaults key for tracking if calibration has been done before
    internal let hasCalibrationBeenPerformedKey = "hasCalibrationBeenPerformedBefore"
    
    // MARK: - Published Properties
    @Published var playerPositions: [CGPoint] = []
    @Published var detectedJoints: [CGPoint?] = Array(repeating: nil, count: 18)
    @Published var originalFrameSize: CGSize = .zero

//    // MARK: - Coordinate Transformation
//    // Helper function to rotate a point 90 degrees clockwise within the frame
//    func rotatePoint90DegreesClockwise(_ point: CGPoint, in size: CGSize) -> CGPoint {
//        // For 90 degrees clockwise rotation:
//        // New x = y
//        // New y = width - x
//        return CGPoint(
//            x: point.y,
//            y: size.width - point.x
//        )
//    }
//    
//    // Helper function to rotate a point 90 degrees clockwise for all coordinate transformations
//    func transformPoint(_ point: CGPoint) -> CGPoint {
//        return rotatePoint90DegreesClockwise(point, in: originalFrameSize)
//    }

    // MARK: - Setup
    private var videoProcessingQueue = DispatchQueue(label: "VideoQueue")
    private var lastPublishTime: Date?
    private let publishInterval: TimeInterval = 0.1
    
    func startSession(in view: UIView, screenSize: CGSize) {
        print("🎥 Starting camera session setup")
        
        // Create a semaphore to synchronize session setup
        let setupSemaphore = DispatchSemaphore(value: 0)
        
        // Stop the session first to ensure clean state
        if session.isRunning {
            session.stopRunning()
        }
        
        // Clean up existing session - use async instead of sync to avoid deadlock
        DispatchQueue.main.async {
            // Remove existing inputs and outputs to avoid "Multiple audio/video AVCaptureInputs" error
            self.session.beginConfiguration()
            
            // Explicitly remove all inputs and outputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }
            
            self.session.commitConfiguration()
            
            // Remove existing preview layer
            self.previewLayer?.removeFromSuperlayer()
            self.previewLayer = nil
            
            // Continue with session setup on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    setupSemaphore.signal()
                    return
                }
                
                print("⚙️ Configuring camera session")
                
                // Get camera device
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    print("❌ Failed to get camera device")
                    setupSemaphore.signal()
                    return
                }
                
                do {
                    // Configure input
                    let input = try AVCaptureDeviceInput(device: device)
                    
                    self.session.beginConfiguration()
                    
                    // Add input
                    guard self.session.canAddInput(input) else {
                        print("❌ Cannot add camera input")
                        self.session.commitConfiguration()
                        setupSemaphore.signal()
                        return
                    }
                    self.session.addInput(input)
                    print("✅ Camera input added successfully")
                    
                    // Configure output
                    let output = AVCaptureVideoDataOutput()
                    output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
                    
                    // Add output
                    guard self.session.canAddOutput(output) else {
                        print("❌ Cannot add video output")
                        self.session.commitConfiguration()
                        setupSemaphore.signal()
                        return
                    }
                    self.session.addOutput(output)
                    self.output = output
                    print("✅ Video output added successfully")
                    
                    // Configure video orientation
                    if let connection = output.connection(with: .video) {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = false
                        }
                    }
                    
                    // Get the original frame size for later use
                    let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                    let originalSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
                    
                    // Commit configuration
                    self.session.commitConfiguration()
                    
                    // Start session after configuration is complete
                    print("▶️ Starting camera session")
                    self.session.startRunning()
                    print("✅ Camera session started")
                    
                    // Update UI on main thread
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // Update original frame size
                        self.originalFrameSize = CGSize(width: CGFloat(originalSize.width), height: CGFloat(originalSize.height))
                        print("📏 Original frame size: \(self.originalFrameSize)")
                        
                        // Configure preview layer
                        let preview = AVCaptureVideoPreviewLayer(session: self.session)
                        preview.videoGravity = .resizeAspectFill
                        
                        // Set the frame to fill the entire view
                        preview.frame = view.bounds
                        
                        view.layer.insertSublayer(preview, at: 0)
                        self.previewLayer = preview
                        print("✅ Preview layer configured with bounds: \(view.bounds)")
                        
                        // Check if calibration has been performed before
                        let defaults = UserDefaults.standard
                        if defaults.bool(forKey: self.hasCalibrationBeenPerformedKey) {
                            self.hasCalibrationBeenPerformedBefore = true
                            self.showRecalibrationPrompt = true
                            print("✅ Calibration has been performed before")
                        } else {
                            print("🎯 First-time user, entering calibration mode")
                            self.isCalibrationMode = true
                            self.resetCalibration()
                        }
                        
                        // Signal that setup is complete
                        setupSemaphore.signal()
                    }
                    
                } catch {
                    print("❌ Error setting up camera: \(error.localizedDescription)")
                    self.session.commitConfiguration()
                    setupSemaphore.signal()
                }
            }
        }
        
        // Wait for a short timeout to ensure setup completes or fails gracefully
        _ = setupSemaphore.wait(timeout: .now() + 5.0)
    }
    
    func updatePreviewFrame(to bounds: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Ensure the preview layer fills the entire view in landscape orientation
            self.previewLayer?.frame = bounds
            self.previewLayer?.videoGravity = .resizeAspectFill
        }
    }

    func stopSession() {
        print("🛑 Stopping camera session")
        
        // Ensure we're not in the middle of configuration
        if session.isRunning {
            // Stop session on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.session.stopRunning()
                
                // Clean up resources on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.previewLayer?.removeFromSuperlayer()
                    self.previewLayer = nil
                    
                    print("✅ Camera session stopped successfully")
                }
            }
        } else {
            print("⚠️ Camera session already stopped")
        }
    }

    func initializeCalibrationPoints(for screenSize: CGSize) {
        // Start with empty arrays - don't initialize with default points
        calibrationPoints = []
        userTappedPoints = []
        calibrationStep = 0
        updateCalibrationInstructions()
    }
    
    func updateCalibrationInstructions() {
        switch calibrationStep {
        case 0:
            calibrationInstructions = "Tap the top-left corner (net, left sideline)"
        case 1:
            calibrationInstructions = "Tap the top-right corner (net, right sideline)"
        case 2:
            calibrationInstructions = "Tap the bottom-left corner (baseline, left sideline)"
        case 3:
            calibrationInstructions = "Tap the bottom-right corner (baseline, right sideline)"
        case 4:
            calibrationInstructions = "Tap the center T-point (where the service line meets the center line)"
        default:
            calibrationInstructions = "All points captured! Tap 'Complete Calibration' to continue"
        }
    }
    
    func resetCalibration() {
        print("🔄 Resetting calibration")
        calibrationStep = 0
        userTappedPoints.removeAll()
        calibrationPoints.removeAll()
        homographyMatrix = nil
        calibrationInstructions = "Tap the top-left corner (net, left sideline)"
        isCalibrationMode = true
        
        // Re-initialize calibration points for the current screen size
        if let screenSize = previewLayer?.bounds.size {
            initializeCalibrationPoints(for: screenSize)
        }
    }

    func handleCalibrationTap(at point: CGPoint) {
        guard isCalibrationMode else { return }
        
        if calibrationStep < 5 {
            // Add the tapped point and print for debugging
            print("👆 User tapped at point: \(point) for step \(calibrationStep)")
            
            // Get the correct bounds for landscape orientation
            let screenBounds = UIScreen.main.bounds
            let landscapeWidth = max(screenBounds.width, screenBounds.height)
            let landscapeHeight = min(screenBounds.width, screenBounds.height)
            
            print("📱 Screen bounds - Width: \(landscapeWidth), Height: \(landscapeHeight)")
            
            // Ensure the point is within bounds
            let boundedPoint = CGPoint(
                x: max(10, min(point.x, landscapeWidth - 10)),
                y: max(10, min(point.y, landscapeHeight - 10))
            )
            
            userTappedPoints.append(boundedPoint)
            print("✅ Added point \(calibrationStep + 1): \(boundedPoint)")
            
            // Increment step and update instructions
            calibrationStep += 1
            updateCalibrationInstructions()
            
            // If we have all 5 points, calculate the full set of calibration points
            if calibrationStep == 5 {
                if let (allImagePoints, _) = CourtLayout.calculateAllReferencePoints(from: userTappedPoints) {
                    // Store the calculated calibration points
                    calibrationPoints = allImagePoints
                    print("✅ Calculated all 8 calibration points from 5 user taps")
                    
                    // Debug print all points
                    for (i, point) in calibrationPoints.enumerated() {
                        print("Calibration point \(i): \(point)")
                    }
                    
                    // Debug print all user tapped points
                    for (i, point) in userTappedPoints.enumerated() {
                        print("User tapped point \(i): \(point)")
                    }
                } else {
                    print("❌ Failed to calculate calibration points")
                }
            }
        }
    }

    func computeHomographyFromCalibrationPoints() {
        guard calibrationPoints.count >= 8 else {
            print("❌ Not enough calibration points, need 8, got \(calibrationPoints.count)")
            return
        }
        
        let courtPoints = CourtLayout.referenceCourtPoints
        
        guard let matrix = HomographyHelper.computeHomographyMatrix(from: calibrationPoints, to: courtPoints) else {
            print("❌ Homography matrix computation failed.")
            return
        }
        self.homographyMatrix = matrix
        
        // Update court lines using the new homography
        let courtLines: [LineSegment] = [
            // Baseline (y = courtLength)
            LineSegment(start: CGPoint(x: 0, y: CourtLayout.courtLength), 
                        end: CGPoint(x: CourtLayout.courtWidth, y: CourtLayout.courtLength)),
            // Right sideline
            LineSegment(start: CGPoint(x: CourtLayout.courtWidth, y: 0), 
                        end: CGPoint(x: CourtLayout.courtWidth, y: CourtLayout.courtLength)),
            // Left sideline
            LineSegment(start: CGPoint(x: 0, y: 0), 
                        end: CGPoint(x: 0, y: CourtLayout.courtLength)),
            // Net line (y = 0)
            LineSegment(start: CGPoint(x: 0, y: 0), 
                        end: CGPoint(x: CourtLayout.courtWidth, y: 0)),
            // Service line
            LineSegment(start: CGPoint(x: 0, y: CourtLayout.serviceLineDistance), 
                        end: CGPoint(x: CourtLayout.courtWidth, y: CourtLayout.serviceLineDistance)),
            // Center line - from net to T-point
            LineSegment(start: CGPoint(x: CourtLayout.courtWidth/2, y: 0), 
                        end: CGPoint(x: CourtLayout.courtWidth/2, y: CourtLayout.serviceLineDistance)),
            // Center line - from T-point to baseline
            LineSegment(start: CGPoint(x: CourtLayout.courtWidth/2, y: CourtLayout.serviceLineDistance), 
                        end: CGPoint(x: CourtLayout.courtWidth/2, y: CourtLayout.courtLength))
        ]
        
        let transformedLines = courtLines.compactMap { line -> LineSegment? in
            guard let p1 = HomographyHelper.projectsForMap(point: line.start, using: matrix, trapezoidCorners: Array(calibrationPoints.prefix(4)), in: nil, screenSize: nil),
                  let p2 = HomographyHelper.projectsForMap(point: line.end, using: matrix, trapezoidCorners: Array(calibrationPoints.prefix(4)), in: nil, screenSize: nil) else {
                return nil
            }
            return LineSegment(start: p1, end: p2)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.projectedCourtLines = transformedLines
        }
    }

    // MARK: - Homography
    func computeCourtHomography(for screenSize: CGSize) {
        // Removed the original implementation
    }

    // MARK: - Frame Processing
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Check if session is running
        guard session.isRunning else {
            print("⚠️ Session not running during frame processing")
            return
        }
        
        // Extract pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("❌ Failed to get pixel buffer from sample buffer")
            return
        }
        
        // Increment frame counter
        frameCounter += 1
        
        // Create a copy of the frame size to avoid capturing pixelBuffer in closures
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        let originalSize = CGSize(width: frameWidth, height: frameHeight)
        
        // Update original frame size on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.originalFrameSize = CGSize(width: CGFloat(originalSize.width), height: CGFloat(originalSize.height))
        }
        
        // Process object detection synchronously to avoid capturing pixelBuffer
        let detectedPlayers = detectPlayersSync(pixelBuffer: pixelBuffer)
        
        // Process the results on a background queue (without capturing pixelBuffer)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Store detected objects
            self.detectedObjects = detectedPlayers
            
            // Process the first detected player (if any)
            if let playerObject = detectedPlayers.first {
                // Process pose for the detected player
                self.processPoseForPlayerSync(pixelBuffer: pixelBuffer, 
                                             playerBox: playerObject, 
                                             originalSize: originalSize)
            }
            
            // Process player position on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.processPlayerPosition()
            }
        }
    }
    
    // Synchronous player detection to avoid capturing pixelBuffer in closures
    private func detectPlayersSync(pixelBuffer: CVPixelBuffer) -> [DetectedObject] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [DetectedObject] = []
        
        objectDetector.detectObjects(in: pixelBuffer) { detectedObjects in
            result = detectedObjects
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    // Synchronous pose processing to avoid capturing pixelBuffer in closures
    private func processPoseForPlayerSync(pixelBuffer: CVPixelBuffer, playerBox: DetectedObject, originalSize: CGSize) {
        let semaphore = DispatchSemaphore(value: 0)
        let currentFrameIndex = self.frameCounter
        
        print("👤 Processing pose for player at frame \(currentFrameIndex)")
        
        playerDetector.processPixelBuffer(pixelBuffer) { [weak self] observation in
            guard let self = self else { 
                semaphore.signal()
                return 
            }
            
            // If we have a pose observation, process it for action classification
            if let observation = observation {
                print("✅ Pose detected for frame \(currentFrameIndex)")
                
                // Pass the pose to the action classifier
                self.actionClassifier.processPose(
                    observation,
                    boundingBox: playerBox.rect,
                    originalSize: originalSize,
                    frameIndex: currentFrameIndex
                )
                
                // Update UI with latest action and predictions on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentAction = self.actionClassifier.currentAction
                    self.actionConfidence = self.actionClassifier.actionConfidence
                    self.predictions = self.actionClassifier.predictions
                    self.detectedJoints = self.actionClassifier.lastDetectedJoints
                    self.originalFrameSize = originalSize
                    
                    print("🎾 Updated action: \(self.currentAction) with confidence: \(self.actionConfidence)")
                    print("👁️ Updated joints: \(self.detectedJoints.compactMap { $0 }.count) valid joints")
                    if !(self.predictions.isEmpty) {
                        print("📊 Current predictions count: \(self.predictions.count)")
                    }
                }
            } else {
                print("⚠️ No pose detected for frame \(currentFrameIndex)")
                
                // Even if no pose is detected, update UI to show "Unknown" action
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentAction = "Unknown"
                    self.actionConfidence = 0.0
                }
            }
            
            semaphore.signal()
        }
        
        semaphore.wait()
    }

    // Process pose for detected player
    private func processPoseForPlayer(pixelBuffer: CVPixelBuffer, playerBox: DetectedObject) {
        // Get the original frame size
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        let originalSize = CGSize(width: frameWidth, height: frameHeight)
        
        // Run pose detection
        playerDetector.processPixelBuffer(pixelBuffer) { observation in
            // If we have a pose observation, process it for action classification
            if let observation = observation {
                // Pass the pose to the action classifier
                self.actionClassifier.processPose(
                    observation,
                    boundingBox: playerBox.rect,
                    originalSize: originalSize,
                    frameIndex: self.frameCounter
                )
                
                // Update UI with latest action
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentAction = self.actionClassifier.currentAction
                    self.actionConfidence = self.actionClassifier.actionConfidence
                    self.predictions = self.actionClassifier.predictions
                }
            }
        }
    }

    // Process player position on the main thread
    private func processPlayerPosition() {
        // Check if we have a homography matrix
        guard let matrix = homographyMatrix else {
            // Only print warning every few seconds to avoid log spam
            if let lastWarning = lastHomographyWarningTime, Date().timeIntervalSince(lastWarning) < 2.0 {
                return
            }
            lastHomographyWarningTime = Date()
            print("❌ Missing homography matrix")
            return
        }
        
        let trapezoidCorners = calibrationPoints.prefix(4)
        
        // Check if we have a foot position
        guard let footPos = objectDetector.bottomCenterPointPositionInImage else {
            // Only print every few seconds to avoid log spam
            if let last = lastFootPositionWarningTime, Date().timeIntervalSince(last) < 2.0 {
                return
            }
            lastFootPositionWarningTime = Date()
            print("ℹ️ No foot position detected")
            return
        }
        
        // Transform foot position to match calibration point orientation
        // The camera is in portrait but UI is in landscape, so we need to transform
        // the foot position coordinates to match the calibration points
        
        // Check if we have valid frame dimensions
        let originalSize = originalFrameSize
        if originalSize.width == 0 || originalSize.height == 0 {
            print("⚠️ Invalid original frame size: \(originalSize)")
            return
        }
        
        // Transform coordinates to match the orientation of calibration points
        // For portrait to landscape right transformation:
        let transformedFootPos = CGPoint(
            x: footPos.y,
            y: originalSize.width - footPos.x
        )
        
        print("🦶 Original foot position: \(footPos), transformed: \(transformedFootPos)")
        
        guard let projected = HomographyHelper.projectsForMap(point: transformedFootPos, using: matrix, trapezoidCorners: Array(trapezoidCorners), in: nil, screenSize: nil) else {
            // Only print every few seconds to avoid log spam
            if let last = lastFootPositionWarningTime, Date().timeIntervalSince(last) < 2.0 {
                return
            }
            lastFootPositionWarningTime = Date()
            print("ℹ️ No foot position detected")
            return
        }
        
        // Update player position
        updatePlayerPosition(projected)
        //print("👟 Detected player position")
    }

    func updatePlayerPosition(_ point: CGPoint) {
        DispatchQueue.main.async { [weak self] in
            // Initialize Kalman filter with first position if needed
            if self?.playerPositionFilter == nil {
                self?.playerPositionFilter = KalmanFilter(
                    initialPosition: point,
                    positionUncertainty: 5.0,  // Moderate initial uncertainty
                    velocityUncertainty: 10.0, // Higher velocity uncertainty
                    processNoise: 0.05,        // Moderate process noise
                    measurementNoise: 0.5      // Relatively low measurement noise (trust measurements)
                )
                print("🔄 Initialized Kalman filter with position: \(point)")
            }
            
            // Update filter with new measurement and get smoothed position
            let timestamp = Date().timeIntervalSince1970
            let smoothedPosition = self?.playerPositionFilter?.update(with: point, at: timestamp)
            
            // Always update the local property for internal use
            self?.projectedPlayerPosition = smoothedPosition
            
            // Only publish to LogicManager at the specified interval
            let now = Date()
            if self?.lastPublishTime == nil || now.timeIntervalSince((self?.lastPublishTime)!) >= (self?.publishInterval ?? 0) {
                self?.playerPositionPublisher.send(smoothedPosition ?? .zero)
                self?.lastPublishTime = now
                
                // Enhanced logging for published positions
                let formattedX = String(format: "%.2f", smoothedPosition?.x ?? 0)
                let formattedY = String(format: "%.2f", smoothedPosition?.y ?? 0)
                let courtPercentX = Int(((smoothedPosition?.x ?? 0) / CourtLayout.courtWidth) * 100)
                let courtPercentY = Int(((smoothedPosition?.y ?? 0) / CourtLayout.courtLength) * 100)
                
                print("📊 Published position: (\(formattedX)m, \(formattedY)m) - \(courtPercentX)% across, \(courtPercentY)% down court")
                
                // Log velocity if available
//                if let filter = self?.playerPositionFilter {
//                    let velocity = filter.currentVelocity
//                    let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
//                    let formattedSpeed = String(format: "%.2f", speed)
//                    self?.playerSpeed = speed
//                    //print("🏃 Player speed: \(formattedSpeed) m/s")
//                }
            }
            
            // Log the difference between raw and smoothed positions (only if significant)
            let dx = (smoothedPosition?.x ?? 0) - point.x
            let dy = (smoothedPosition?.y ?? 0) - point.y
            let distance = sqrt(dx*dx + dy*dy)
//            if distance > 0.1 { // Only log if difference is significant
//                print("🧮 Kalman smoothing: diff=\(String(format: "%.2f", distance))m")
//            }
        }
    }

    // MARK: - Initialization
    override init() {
        super.init()
        
        // Subscribe to action classifier updates
        actionClassifier.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (action, confidence) in
                guard let self = self else { return }
                self.currentAction = action
                self.actionConfidence = confidence
                self.actionPublisher.send((action, confidence))
            }
            .store(in: &cancellables)
        
        // Check if calibration has been performed before
        let defaults = UserDefaults.standard
        hasCalibrationBeenPerformedBefore = defaults.bool(forKey: hasCalibrationBeenPerformedKey)
    }

    func resetSession() {
        print("🔄 Resetting camera session")
        stopSession()
        
        // Reset action classifier
        actionClassifier.reset()
        frameCounter = 0
        currentAction = "Unknown"
        actionConfidence = 0.0
        
        // Reset other components
        playerPositionFilter = nil
        projectedPlayerPosition = nil
        playerSpeed = 0.0
        
        // Start session again if there's a valid preview layer
        if let previewView = previewLayer?.superlayer as? UIView,
           let screenSize = previewLayer?.bounds.size {
            startSession(in: previewView, screenSize: screenSize)
        } else {
            print("⚠️ Cannot restart session: no valid preview layer")
        }
    }
}
