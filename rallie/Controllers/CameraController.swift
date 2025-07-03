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
    @Published var isTappingEnabled = false
    
    // MARK: - Calibration Points
    @Published var calibrationPoints: [CGPoint] = []
    @Published var isCalibrationMode = true

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

            // Initialize calibration points instead of computing homography directly
            initializeCalibrationPoints(for: screenSize)
            
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
        let width = screenSize.width
        let height = screenSize.height

        // 4 outer corner points
        let bottomLeft = CGPoint(x: width * 0.2, y: height * 0.79)     // blue
        let bottomRight = CGPoint(x: width * 0.85, y: height * 0.79)    // green
        let topRight = CGPoint(x: width * 0.95, y: height * 0.22)       // yellow
        let topLeft = CGPoint(x: width * 0.1, y: height * 0.2)       // pink

        calibrationPoints = [bottomLeft, bottomRight, topRight, topLeft]

        // Service line Y (between top and bottom)
        let serviceLineY = topLeft.y + (bottomLeft.y - topLeft.y) * 0.5

        // Interpolated X positions for service line (match trapezoid perspective)
        let leftServiceX = bottomLeft.x + (topLeft.x - bottomLeft.x) * ((serviceLineY - bottomLeft.y) / (topLeft.y - bottomLeft.y))
        let rightServiceX = bottomRight.x + (topRight.x - bottomRight.x) * ((serviceLineY - bottomRight.y) / (topRight.y - bottomRight.y))

        // Center X for vertical service line
        let centerX = (leftServiceX + rightServiceX) / 2

        // Add inner service line points
        calibrationPoints.append(CGPoint(x: leftServiceX, y: serviceLineY))   // orange
        calibrationPoints.append(CGPoint(x: rightServiceX, y: serviceLineY))  // red
        calibrationPoints.append(CGPoint(x: centerX, y: serviceLineY))        // center blue
        calibrationPoints.append(CGPoint(x: centerX, y: serviceLineY))        // center blue (copy)
    }




    
    
//    func computeHomographyFromCalibrationPoints() {
//        guard calibrationPoints.count >= 4 else {
//            print("❌ Not enough calibration points ",(calibrationPoints))
//            return
//        }
//        
//        let courtPoints = CourtLayout.referenceCourtPoints
//        
////        guard let matrix = HomographyHelper.computeHomographyMatrix(from: calibrationPoints, to: courtPoints) else {
////            print("❌ Homography matrix computation failed.")
////            return
////        }
//        
//        let matrix = HomographyHelper.computeHomographyMatrix(from: calibrationPoints, to: courtPoints)
//        
//        self.homographyMatrix = matrix
//        
//        // Update court lines using the new homography
//        let courtLines: [LineSegment] = [
//            // Baseline (y = 0)
//            LineSegment(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 8.23, y: 0)),
//            // Right sideline
//            LineSegment(start: CGPoint(x: 8.23, y: 0), end: CGPoint(x: 8.23, y: 11.885)),
//            // Net line (y = 11.885)
//            LineSegment(start: CGPoint(x: 8.23, y: 11.885), end: CGPoint(x: 0, y: 11.885)),
//            // Left sideline
//            LineSegment(start: CGPoint(x: 0, y: 11.885), end: CGPoint(x: 0, y: 0)),
//        ]
//        
//        
//        
//        
//        let transformedLines = courtLines.compactMap { line -> LineSegment? in
//             let p1 = HomographyHelper.projectsForMap(point: line.start, using: matrix!, trapezoidCorners: Array(calibrationPoints.prefix(4)))
//                  let p2 = HomographyHelper.projectsForMap(point: line.end, using: matrix!, trapezoidCorners: Array(calibrationPoints.prefix(4)))
//            return LineSegment(start: p1!, end: p2!)
//        }
//        
//        DispatchQueue.main.async {
//            self.projectedCourtLines = transformedLines
//        }
//    }

    

    func computeHomographyFromCalibrationPoints() {
        guard calibrationPoints.count >= 4 else {
            print("❌ Not enough calibration points")
            return
        }
        
        let courtPoints = CourtLayout.referenceCourtPoints
        
        guard let matrix = HomographyHelper.computeHomographyMatrix(from: calibrationPoints, to: courtPoints) else {
            print("❌ Homography matrix computation failed.")
            return
        }
        self.homographyMatrix = matrix
//        
//        // Update court lines using the new homography
        let courtLines: [LineSegment] = [
            // Baseline (y = 0)
            LineSegment(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 8.23, y: 0)),
            // Right sideline
            LineSegment(start: CGPoint(x: 8.23, y: 0), end: CGPoint(x: 8.23, y: 11.885)),
            // Net line (y = 11.885)
            LineSegment(start: CGPoint(x: 8.23, y: 11.885), end: CGPoint(x: 0, y: 11.885)),
            // Left sideline
            LineSegment(start: CGPoint(x: 0, y: 11.885), end: CGPoint(x: 0, y: 0)),
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

    // MARK: - Tap Handling
    func handleUserTap(_ location: CGPoint) {
        guard let matrix = homographyMatrix else {
            print("❌ Missing homography matrix")
            return
        }
        
        let trapezoidCorners = calibrationPoints.prefix(4)
        
        guard let projected = HomographyHelper.projectsForMap(point: location, using: matrix, trapezoidCorners: Array(trapezoidCorners)) else {
            print("❌ Tap projection failed")
            return
        }

        if (0...8.23).contains(projected.x) && (0...11.885).contains(projected.y) {
            DispatchQueue.main.async {
                self.lastProjectedTap = projected
                print("✅ Tap accepted: \(projected)")
            }
        } else {
            print("⚠️ Tap outside bounds: \(projected)")
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
