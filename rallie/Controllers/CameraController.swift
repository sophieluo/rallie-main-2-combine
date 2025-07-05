// MARK: - CameraController.swift

import Foundation
import AVFoundation
import UIKit
import Vision
import Combine

class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    public var previewLayer: AVCaptureVideoPreviewLayer?
    private var output: AVCaptureVideoDataOutput?
    private var lastLogTime: Date? = nil

    // MARK: - Vision
    private(set) var overlayView = BoundingBoxOverlayView()
        
        private let objectDetector = ObjectDetector()
        
         var detectedObjects: [DetectedObject] = [] {
            didSet {
                DispatchQueue.main.async {
//                    self.overlayView.boxes = self.detectedObjects
                }
            }
        }

    // MARK: - Outputs
    @Published var projectedCourtLines: [LineSegment] = []
    @Published var lastProjectedTap: CGPoint? = nil
    @Published var homographyMatrix: [NSNumber]? = nil
    @Published var projectedPlayerPosition: CGPoint? = nil
    @Published var isTappingEnabled = true
    
    // MARK: - Calibration Points
    @Published var calibrationPoints: [CGPoint] = []
    @Published var userTappedPoints: [CGPoint] = []
    @Published var isCalibrationMode = false
    @Published var calibrationStep = 0
    @Published var calibrationInstructions = "Tap the top-left corner (net, left sideline)"
    
    // Debug flag to help troubleshoot calibration issues
    private var debugCalibration = true

    // MARK: - Setup
    func startSession(in view: UIView, screenSize: CGSize) {
        print("🎥 Starting camera session setup")
        
        // Check if session is already running
        guard !session.isRunning else {
            print("⚠️ Session already running")
            return
        }

        session.sessionPreset = .high
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        initializeCalibrationPoints(for: screenSize)
        
        isCalibrationMode = true
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ Failed to get camera device")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                print("❌ Cannot add camera input")
                return
            }
            session.addInput(input)
            print("✅ Camera input added successfully")
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
            guard session.canAddOutput(output) else {
                print("❌ Cannot add video output")
                return
            }
            session.addOutput(output)
            self.output = output
            print("✅ Video output added successfully")

            previewLayer?.removeFromSuperlayer()
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            preview.connection?.videoOrientation = .landscapeRight
            view.layer.insertSublayer(preview, at: 0)
            self.previewLayer = preview
            print("✅ Preview layer configured")

            session.beginConfiguration()
            if let connection = output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .landscapeRight
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                print("🎬 Starting capture session")
                self?.session.startRunning()
                print("✅ Capture session started")
            }

        } catch {
            print("❌ Camera setup error: \(error.localizedDescription)")
        }
    }

    func stopSession() {
        print("🛑 Stopping camera session")
        session.stopRunning()
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer?.removeFromSuperlayer()
            self?.previewLayer = nil
            self?.output = nil
        }
        print("✅ Camera session stopped")
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
    
    func handleCalibrationTap(at point: CGPoint) {
        guard isCalibrationMode else { return }
        
        if calibrationStep < 5 {
            // Add the tapped point and print for debugging
            print("👆 User tapped at point: \(point) for step \(calibrationStep)")
            
            // Store the user tapped point - ensure it's visible on screen
            let screenBounds = UIScreen.main.bounds
            let boundedPoint = CGPoint(
                x: max(10, min(point.x, screenBounds.width - 10)),
                y: max(10, min(point.y, screenBounds.height - 10))
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
            // Center line - extend it from net to baseline to ensure it passes through the center T-point
            LineSegment(start: CGPoint(x: CourtLayout.courtWidth/2, y: 0), 
                        end: CGPoint(x: CourtLayout.courtWidth/2, y: CourtLayout.courtLength))
        ]
        
        let transformedLines = courtLines.compactMap { line -> LineSegment? in
            guard let p1 = HomographyHelper.projectsForMap(point: line.start, using: matrix, trapezoidCorners: Array(calibrationPoints.prefix(4))),
                  let p2 = HomographyHelper.projectsForMap(point: line.end, using: matrix, trapezoidCorners: Array(calibrationPoints.prefix(4))) else {
                return nil
            }
            return LineSegment(start: p1, end: p2)
        }
        
        DispatchQueue.main.async {
            self.projectedCourtLines = transformedLines
        }
    }

    // MARK: - Homography
    func computeCourtHomography(for screenSize: CGSize) {
        // Removed the original implementation
    }

    // MARK: - Frame Processing
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("❌ Failed to get pixel buffer")
            return
        }
        
        if !session.isRunning {
            print("⚠️ Session not running during frame processing")
            return
        }
        
//        playerDetector.processPixelBuffer(pixelBuffer)
        
        objectDetector.detectObjects(in: pixelBuffer) { [weak self] detected in
                   guard let self = self else { return }
             self.detectedObjects = detected
              
        }

        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let matrix = self.homographyMatrix else {
                print("❌ Missing homography matrix")
                return
            }
            
            let trapezoidCorners = self.calibrationPoints.prefix(4)
            
            guard let footPos = self.objectDetector.bottomcentrePointPositionInImage else {
                // Only print every few seconds to avoid log spam
                if let last = self.lastLogTime, Date().timeIntervalSince(last) > 2.0 {
                    print("ℹ️ No foot position detected")
                    self.lastLogTime = Date()
                }
                return
            }
            
            if let projected = HomographyHelper.projectsForMap(point: footPos, using: matrix, trapezoidCorners: Array(trapezoidCorners)) {
                self.projectedPlayerPosition = projected
                self.logPlayerPositionCSV(projected)
                print("👟 Projected feet: \(projected)")
                self.updatePlayerPosition(projected)
            }
            
            
          
        }
    }

    // MARK: - User Interaction
    func handleTap(at point: CGPoint) {
        guard isTappingEnabled else { return }
        
        // Process the tap location
        print("👆 User tapped at: \(point)")
        
        // If we have a homography matrix, project the tap to court coordinates
        if let matrix = homographyMatrix {
            if let projected = HomographyHelper.projectsForMap(point: point, using: matrix, trapezoidCorners: Array(calibrationPoints.prefix(4))) {
                print("📍 Projected tap to court coordinates: \(projected)")
            }
        }
    }

    func updatePreviewFrame(to bounds: CGRect) {
        DispatchQueue.main.async {
            self.previewLayer?.frame = bounds
        }
    }
    
    private func logPlayerPositionCSV(_ point: CGPoint) {
        let now = Date()

        // Only log if at least 1 second has passed
        if let last = lastLogTime, now.timeIntervalSince(last) < 1.0 {
            return
        }

        lastLogTime = now

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: now)

        let row = "\(timestamp),\(point.x),\(point.y)\n"
        let fileName = "player_positions.csv"

        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get document directory")
            return
        }

        let fileURL = dir.appendingPathComponent(fileName)
        print("📝 CSV Path: \(fileURL.path)")

        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                // Create new file with header
                let header = "timestamp,x,y\n"
                try (header + row).write(to: fileURL, atomically: true, encoding: .utf8)
                print("✅ Created new CSV file with header")
            } else {
                // Append to existing file
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { handle.closeFile() } // Ensures file is closed even if an error occurs
                
                handle.seekToEndOfFile()
                if let data = row.data(using: .utf8) {
                    handle.write(data)
                    print("✅ Appended position: \(point.x), \(point.y)")
                }
            }
        } catch {
            print("❌ CSV write error: \(error.localizedDescription)")
        }
    }

    // Add this helper method to get the CSV file URL
    func getCSVFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("player_positions.csv")
    }

    let playerPositionPublisher = PassthroughSubject<CGPoint, Never>()

    private func updatePlayerPosition(_ point: CGPoint) {
        DispatchQueue.main.async {
            self.projectedPlayerPosition = point
            self.playerPositionPublisher.send(point) // ✅ broadcast position
        }
    }
}
