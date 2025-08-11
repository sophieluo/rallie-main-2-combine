//
//  ActionClassifier.swift
//  rallie
//
//  Created on 2025-08-06.
//

import Foundation
import Vision
import CoreML
import SwiftUI
import Combine

class ActionClassifier: ObservableObject {
    // MARK: - Published Properties
    @Published var currentAction: String = "Unknown"
    @Published var actionConfidence: Float = 0.0
    @Published var predictions: [(startFrame: Int, endFrame: Int, label: String, confidence: Float)] = []
    @Published var lastDetectedJoints: [CGPoint?] = Array(repeating: nil, count: 18)
    @Published var isCollectingPoses: Bool = false
    
    // MARK: - Model
    private var actionClassifierModel: MLModel?
    
    // MARK: - Pose Sequence Buffer
    private var poseFrames: [[[Float]]] = [] // [frame][x/y/conf][joint]
    private let requiredFrameCount = 30
    private let requiredJointCount = 18
    private var frameCounter: Int = 0
    
    // MARK: - Publishers
    let actionPublisher = PassthroughSubject<(String, Float), Never>()
    
    // MARK: - Initialization
    init() {
        print("🏃‍♂️ ActionClassifier: Initializing")
        loadModel()
    }
    
    private func loadModel() {
        print("🏃‍♂️ ActionClassifier: Loading model")
        
        // Try to load the raw model first (preferred)
        if let modelURL = Bundle.main.url(forResource: "TennisClassifier", withExtension: "mlmodel") {
            print("🏃‍♂️ ActionClassifier: Found raw model at \(modelURL.path)")
            do {
                actionClassifierModel = try MLModel(contentsOf: modelURL)
                print("✅ ActionClassifier: Successfully loaded raw model")
                
                // Print model description for debugging
                print("📋 Model Input Description:")
                for (name, desc) in actionClassifierModel!.modelDescription.inputDescriptionsByName {
                    print("   - Input: \(name), Type: \(desc.type), Shape: \(String(describing: desc.multiArrayConstraint?.shape))")
                }
                
                print("📋 Model Output Description:")
                for (name, desc) in actionClassifierModel!.modelDescription.outputDescriptionsByName {
                    print("   - Output: \(name), Type: \(desc.type)")
                }
            } catch {
                print("❌ ActionClassifier: Failed to load raw model: \(error.localizedDescription)")
            }
        } 
        // If raw model not found, try loading the compiled model
        else if let modelURL = Bundle.main.url(forResource: "TennisClassifier", withExtension: "mlmodelc") {
            print("🏃‍♂️ ActionClassifier: Found compiled model at \(modelURL.path)")
            do {
                actionClassifierModel = try MLModel(contentsOf: modelURL)
                print("✅ ActionClassifier: Successfully loaded compiled model")
                
                // Print model description for debugging
                print("📋 Model Input Description:")
                for (name, desc) in actionClassifierModel!.modelDescription.inputDescriptionsByName {
                    print("   - Input: \(name), Type: \(desc.type), Shape: \(String(describing: desc.multiArrayConstraint?.shape))")
                }
                
                print("📋 Model Output Description:")
                for (name, desc) in actionClassifierModel!.modelDescription.outputDescriptionsByName {
                    print("   - Output: \(name), Type: \(desc.type)")
                }
            } catch {
                print("❌ ActionClassifier: Failed to load compiled model: \(error.localizedDescription)")
            }
        } else {
            print("❌ ActionClassifier: Could not find TennisClassifier model in bundle")
        }
    }
    
    // MARK: - Process Pose
    func processPose(_ observation: VNHumanBodyPoseObservation, boundingBox: CGRect, originalSize: CGSize, frameIndex: Int) {
        // Extract all keypoints
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            print("❌ Failed to extract keypoints from pose observation")
            return
        }
        
        // Map Vision keypoints to our required 18 keypoints
        var keypoints: [CGPoint?] = Array(repeating: nil, count: 18)
        // Use a point far off-screen that will be easily identifiable as "not set"
        // This avoids the issue of undetected joints defaulting to (0,0) which appears in the upper left corner
        let unsetPoint = CGPoint(x: -9999, y: -9999)
        var pixelKeypoints: [CGPoint] = Array(repeating: unsetPoint, count: 18)
        
        // Map the Vision keypoints to our model's expected format
        // IMPORTANT: The order of keypoints must match what the model expects
        // From documentation: "nose, neck, right shoulder, right elbow, right wrist, left shoulder, left elbow, left wrist, 
        // right hip, right knee, right ankle, left hip, left knee, left ankle, right eye, left eye, right ear, left ear"
        
        // Map Vision keypoints to our format - keep normalized coordinates for the model
        // And create pixel coordinates for visualization
        mapJoint(recognizedPoints[.nose], index: 0, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        
        // 1: neck (approximated as midpoint between shoulders if not available)
        if let neck = recognizedPoints[.neck], neck.confidence > 0.1 {
            keypoints[1] = CGPoint(
                x: (1 - neck.location.y),  // Swap x/y and flip x
                y: (1 - neck.location.x)   // Swap x/y and flip y
            )
            pixelKeypoints[1] = CGPoint(
                x: (1 - neck.location.y) * originalSize.width,
                y: (1 - neck.location.x) * originalSize.height
            )
        } else if let leftShoulder = recognizedPoints[.leftShoulder], 
                  let rightShoulder = recognizedPoints[.rightShoulder],
                  leftShoulder.confidence > 0.1, rightShoulder.confidence > 0.1 {
            // Calculate midpoint between shoulders for neck
            let midX = (leftShoulder.location.x + rightShoulder.location.x) / 2
            let midY = (leftShoulder.location.y + rightShoulder.location.y) / 2
            
            // Map to our coordinate system (swap and flip)
            let mappedX = 1 - midY
            let mappedY = 1 - midX
            
            keypoints[1] = CGPoint(x: mappedX, y: mappedY)
            
            // Map to pixel coordinates for visualization
            pixelKeypoints[1] = CGPoint(
                x: mappedX * originalSize.width,
                y: mappedY * originalSize.height
            )
        }
        
        mapJoint(recognizedPoints[.rightShoulder], index: 2, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        
        mapJoint(recognizedPoints[.rightElbow], index: 3, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.rightWrist], index: 4, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftShoulder], index: 5, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftElbow], index: 6, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftWrist], index: 7, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.rightHip], index: 8, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.rightKnee], index: 9, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.rightAnkle], index: 10, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftHip], index: 11, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftKnee], index: 12, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftAnkle], index: 13, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.rightEye], index: 14, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftEye], index: 15, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.rightEar], index: 16, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        mapJoint(recognizedPoints[.leftEar], index: 17, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        
        let validJointCount = keypoints.compactMap { $0 }.count
        
        // Update the last detected joints for visualization - ensure on main thread
        DispatchQueue.main.async { [weak self] in
            // Convert any remaining zero points to nil before updating lastDetectedJoints
            let filteredPixelKeypoints: [CGPoint?] = pixelKeypoints.map { point in
                // If the point is at or very near (0,0) or is our unset point, return nil instead
                return (abs(point.x) < 1 && abs(point.y) < 1) || 
                       (point.x < -9000 && point.y < -9000) ? nil : point
            }
            
            self?.lastDetectedJoints = filteredPixelKeypoints
        }
        
        // Create the normalized keypoints array in the format expected by the model
        var normalizedKeypoints: [[Float]] = Array(repeating: Array(repeating: 0.0, count: 18), count: 3)
        
        // Fill the array with normalized coordinates
        for i in 0..<keypoints.count {
            if let point = keypoints[i] {
                // Only include valid points in the model input
                // Check if this is a valid point (not an outlier)
                let isValidPoint = point != .zero && 
                                  point.x >= 0 && point.x <= 1 && 
                                  point.y >= 0 && point.y <= 1
                
                if isValidPoint {
                    normalizedKeypoints[0][i] = Float(point.x)  // x coordinate
                    normalizedKeypoints[1][i] = Float(point.y)  // y coordinate
                    normalizedKeypoints[2][i] = 1.0  // confidence for valid points
                } else {
                    // For invalid points, set confidence to 0
                    normalizedKeypoints[0][i] = 0.0
                    normalizedKeypoints[1][i] = 0.0
                    normalizedKeypoints[2][i] = 0.0
                }
            } else {
                // For nil points (filtered out earlier), set confidence to 0
                normalizedKeypoints[0][i] = 0.0
                normalizedKeypoints[1][i] = 0.0
                normalizedKeypoints[2][i] = 0.0
            }
        }
        
        // Special handling for right shoulder (index 2) which is prone to mapping errors
        // If we have a neck point (index 1), check if right shoulder is too far
        if let neck = keypoints[1], let rightShoulder = keypoints[2] {
            let distance = sqrt(pow(neck.x - rightShoulder.x, 2) + pow(neck.y - rightShoulder.y, 2))
            
            // If distance is too large, this is likely a mapping error
            if distance > 0.3 {  // Threshold for normalized coordinates (0-1)
                // Zero out the right shoulder in the model input
                normalizedKeypoints[0][2] = 0.0
                normalizedKeypoints[1][2] = 0.0
                normalizedKeypoints[2][2] = 0.0
            }
        }
        
        // Add to pose buffer
        addToPoseBuffer(normalizedKeypoints, frameIndex: frameIndex)
    }
    
    // Helper method to map keypoints
    private func mapJoint(_ point: VNRecognizedPoint?, index: Int, keypoints: inout [CGPoint?], pixelKeypoints: inout [CGPoint], originalSize: CGSize) {
        // For right shoulder (index 2), increase confidence threshold to 0.5
        let confidenceThreshold: CGFloat = index == 2 ? 0.5 : 
                                          (index >= 9 && index <= 14) ? 0.3 : 0.1
        
        if let point = point, CGFloat(point.confidence) > confidenceThreshold {
            // Map normalized coordinates for model input (swap and flip due to camera orientation)
            let mappedPoint = CGPoint(
                x: (1 - point.location.y),
                y: (1 - point.location.x)
            )
            
            // Validate coordinates are within normalized range [0,1]
            if mappedPoint.x >= 0 && mappedPoint.x <= 1 && mappedPoint.y >= 0 && mappedPoint.y <= 1 {
                keypoints[index] = mappedPoint
                
                // Map to pixel coordinates for visualization
                let pixelX = mappedPoint.x * originalSize.width
                let pixelY = mappedPoint.y * originalSize.height
                pixelKeypoints[index] = CGPoint(x: pixelX, y: pixelY)
            }
        }
    }
    
    // MARK: - Pose Buffer Management
    private func addToPoseBuffer(_ normalizedKeypoints: [[Float]], frameIndex: Int) {
        // Start collecting poses
        if !isCollectingPoses {
            isCollectingPoses = true
            frameCounter = frameIndex
        }
        
        // Add the current frame's keypoints to the buffer
        poseFrames.append(normalizedKeypoints)
        
        // If we have enough frames, run the classifier
        if poseFrames.count >= requiredFrameCount {
            // Run classifier with a sliding window
            let startIdx = max(0, poseFrames.count - requiredFrameCount)
            let endIdx = poseFrames.count
            let frameWindow = Array(poseFrames[startIdx..<endIdx])
            
            // Run action classifier
            runActionClassifier(poseFrames: frameWindow, startFrame: frameIndex - frameWindow.count + 1, endFrame: frameIndex)
            
            // Slide window (remove oldest frame if buffer exceeds required size)
            if poseFrames.count > requiredFrameCount {
                poseFrames.removeFirst()
            }
        }
    }
    
    // MARK: - Action Classification
    private func runActionClassifier(poseFrames: [[[Float]]], startFrame: Int, endFrame: Int) {
        guard let model = actionClassifierModel else {
            return
        }
        
        do {
            // Create MLMultiArray with the exact shape expected by the model
            let inputShape = [NSNumber(value: 30), NSNumber(value: 3), NSNumber(value: 18)]
            guard let multiArray = try? MLMultiArray(shape: inputShape, dataType: .float32) else {
                return
            }
            
            // Fill the MLMultiArray with pose data
            for frameIdx in 0..<min(poseFrames.count, 30) {
                let frameData = poseFrames[frameIdx]
                for coordIdx in 0..<3 { // x, y, confidence
                    for jointIdx in 0..<18 {
                        // Calculate the index in the multi-array
                        let index = [frameIdx, coordIdx, jointIdx] as [NSNumber]
                        multiArray[index] = NSNumber(value: frameData[coordIdx][jointIdx])
                    }
                }
            }
            
            // Create input dictionary for the model
            // Use the exact input feature name from the model description
            let inputName = "poses"
            let inputDict = [inputName: multiArray]
            
            // Run inference
            let outputFeatures = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: inputDict))
            
            // Extract prediction
            guard let labelOutput = outputFeatures.featureValue(for: "label")?.stringValue else {
                return
            }
            
            var confidence: Float = 0.0
            if let probsOutput = outputFeatures.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: NSNumber] {
                confidence = probsOutput[labelOutput]?.floatValue ?? 0.0
            }
            
            // Only update if confidence is above a threshold
            if confidence > 0.6 {
                // Store prediction
                let prediction = (startFrame: startFrame, endFrame: endFrame, label: labelOutput, confidence: confidence)
                predictions.append(prediction)
                
                // Update UI on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentAction = labelOutput
                    self.actionConfidence = confidence
                    
                    // Notify observers
                    self.objectWillChange.send()
                }
            }
        } catch {
            print("❌ Error running action classifier: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reset
    func reset() {
        poseFrames.removeAll()
        predictions.removeAll()
        currentAction = "Unknown"
        actionConfidence = 0.0
        isCollectingPoses = false
        frameCounter = 0
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    // MARK: - Map Vision Points to Pixels
    private func mapVisionPointsToPixels(_ recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint], originalSize: CGSize) -> [CGPoint?] {
        // This method is no longer used - we're using the pixelKeypoints array from processPose instead
        // Keeping this stub for now in case it's called elsewhere, but it should be removed in the future
        print("⚠️ Warning: mapVisionPointsToPixels is deprecated and should not be called")
        return Array(repeating: nil, count: 18)
    }
}
