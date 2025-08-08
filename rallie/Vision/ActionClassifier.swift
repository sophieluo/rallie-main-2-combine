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
        
        print("🏃 Processing pose for frame \(frameIndex), found \(recognizedPoints.count) keypoints")
        
        // Map Vision keypoints to our required 18 keypoints
        var keypoints: [CGPoint?] = Array(repeating: nil, count: 18)
        var pixelKeypoints: [CGPoint] = Array(repeating: .zero, count: 18)
        
        // Debug: Print all recognized points from Vision
        print("🔍 All recognized points from Vision:")
        for (key, point) in recognizedPoints {
            if point.confidence > 0.1 {
                print("  \(key): (\(point.location.x), \(point.location.y)), conf: \(point.confidence)")
            }
        }
        
        // IMPORTANT: The order of keypoints must match what the model expects
        // From documentation: "nose, neck, right shoulder, right elbow, right wrist, left shoulder, left elbow, left wrist, 
        // right hip, right knee, right ankle, left hip, left knee, left ankle, right eye, left eye, right ear, left ear"
        
        // Map Vision keypoints to our format - keep normalized coordinates for the model
        // And create pixel coordinates for visualization
        mapJoint(recognizedPoints[.nose], index: 0, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        
        // 1: neck (approximated as midpoint between shoulders if not available)
        if let neck = recognizedPoints[.neck], neck.confidence > 0.1 {
            print("🔍 Using direct neck detection: (\(neck.location.x), \(neck.location.y)), confidence: \(neck.confidence)")
            keypoints[1] = CGPoint(
                x: (1 - neck.location.y),  // Swap x/y and flip x
                y: (1 - neck.location.x)   // Swap x/y and flip y
            )
            pixelKeypoints[1] = CGPoint(
                x: (1 - neck.location.y) * originalSize.width,
                y: (1 - neck.location.x) * originalSize.height
            )
            print("🔍 Neck joint (direct) - Model input: (\(keypoints[1]!.x), \(keypoints[1]!.y)), Pixel: (\(pixelKeypoints[1].x), \(pixelKeypoints[1].y))")
        } else if let leftShoulder = recognizedPoints[.leftShoulder], 
                  let rightShoulder = recognizedPoints[.rightShoulder],
                  leftShoulder.confidence > 0.1, rightShoulder.confidence > 0.1 {
            print("🔍 Using shoulder midpoint for neck: Left (\(leftShoulder.location.x), \(leftShoulder.location.y)), Right (\(rightShoulder.location.x), \(rightShoulder.location.y))")
            
            // For midpoint calculation, we need to handle the orientation consistently
            // We'll swap x/y first, then calculate the midpoint
            let leftX = leftShoulder.location.y
            let leftY = leftShoulder.location.x
            let rightX = rightShoulder.location.y
            let rightY = rightShoulder.location.x
            
            let midX = (leftX + rightX) / 2
            let midY = (leftY + rightY) / 2
            
            print("🔍 Calculated neck midpoint (after swap): (\(midX), \(midY))")
            
            // Apply flipping for model input
            keypoints[1] = CGPoint(
                x: (1 - midX),  // Flip x
                y: (1 - midY)   // Flip y
            )
            pixelKeypoints[1] = CGPoint(
                x: (1 - midX) * originalSize.width,
                y: (1 - midY) * originalSize.height
            )
            print("🔍 Neck joint (midpoint) - Model input: (\(keypoints[1]!.x), \(keypoints[1]!.y)), Pixel: (\(pixelKeypoints[1].x), \(pixelKeypoints[1].y))")
        } else {
            print("⚠️ Could not determine neck position - no direct detection or valid shoulders")
        }
        
        // Map remaining keypoints
        mapJoint(recognizedPoints[.rightShoulder], index: 2, keypoints: &keypoints, pixelKeypoints: &pixelKeypoints, originalSize: originalSize)
        
        // Debug: Print detailed comparison of neck and right shoulder positions
        print("🔎🔎🔎 JOINT_DEBUG: DETAILED JOINT COMPARISON 🔎🔎🔎")
        if let neck = keypoints[1], let rightShoulder = keypoints[2] {
            print("🔎🔎🔎 JOINT_DEBUG: Neck (index 1): Model input: (\(neck.x), \(neck.y)), Pixel: (\(pixelKeypoints[1].x), \(pixelKeypoints[1].y))")
            print("🔎🔎🔎 JOINT_DEBUG: Right Shoulder (index 2): Model input: (\(rightShoulder.x), \(rightShoulder.y)), Pixel: (\(pixelKeypoints[2].x), \(pixelKeypoints[2].y))")
            print("🔎🔎🔎 JOINT_DEBUG: Distance between neck and right shoulder: Model: \(sqrt(pow(neck.x - rightShoulder.x, 2) + pow(neck.y - rightShoulder.y, 2))), Pixel: \(sqrt(pow(pixelKeypoints[1].x - pixelKeypoints[2].x, 2) + pow(pixelKeypoints[1].y - pixelKeypoints[2].y, 2)))")
        }
        
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
        
        // Print debug info about detected joints
        let validJointCount = keypoints.compactMap { $0 }.count
        print("🦴 Detected \(validJointCount)/18 valid joints for visualization")
        
        // Update the last detected joints for visualization - ensure on main thread
        DispatchQueue.main.async { [weak self] in
            self?.lastDetectedJoints = pixelKeypoints
            print("🔄 Updated joints for visualization: \(validJointCount) valid joints")
            
            // Simple debug print for each joint position
            print("SIMPLE_DEBUG: Joint positions:")
            for (i, point) in pixelKeypoints.enumerated() {
                if point != .zero {
                    print("SIMPLE_DEBUG: Joint \(i): (\(Int(point.x)), \(Int(point.y)))")
                    
                    // Check if this joint is far from the center (potential stray)
                    let centerX = originalSize.width / 2
                    let centerY = originalSize.height / 2
                    let distanceFromCenter = sqrt(pow(point.x - centerX, 2) + pow(point.y - centerY, 2))
                    
                    if distanceFromCenter > max(originalSize.width, originalSize.height) * 0.4 {
                        print("SIMPLE_DEBUG: ⚠️ POTENTIAL STRAY JOINT: Joint \(i) is far from center: \(Int(distanceFromCenter)) pixels")
                    }
                }
            }
            
            // Check specific connections
            if pixelKeypoints[1] != .zero && pixelKeypoints[2] != .zero {
                let distance = sqrt(pow(pixelKeypoints[2].x - pixelKeypoints[1].x, 2) + 
                                   pow(pixelKeypoints[2].y - pixelKeypoints[1].y, 2))
                print("SIMPLE_DEBUG: Neck to Right Shoulder distance: \(Int(distance)) pixels")
                if distance > 200 {
                    print("SIMPLE_DEBUG: ⚠️ UNUSUALLY LONG CONNECTION: Neck to Right Shoulder: \(Int(distance)) pixels")
                }
            }
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
                    print("⚠️ Excluding invalid point from model input: joint \(i)")
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
                print("⚠️ Right shoulder too far from neck in model input: \(distance)")
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
                // Special handling for right shoulder (index 2)
                if index == 2 {
                    // Check if right shoulder is too far from neck (if neck exists)
                    if let neckPoint = keypoints[1] {
                        let distance = sqrt(pow(mappedPoint.x - neckPoint.x, 2) + pow(mappedPoint.y - neckPoint.y, 2))
                        print("🔍 Right shoulder to neck distance (normalized): \(distance)")
                        
                        // If distance is too large, discard this point
                        if distance > 0.3 {
                            print("⚠️ Right shoulder is too far from neck (\(distance)), discarding")
                            return
                        }
                    }
                }
                
                keypoints[index] = mappedPoint
                
                // Map to pixel coordinates for visualization
                let pixelX = mappedPoint.x * originalSize.width
                let pixelY = mappedPoint.y * originalSize.height
                pixelKeypoints[index] = CGPoint(x: pixelX, y: pixelY)
                
                // Print debug info for key joints
                if index == 1 || index == 2 || index == 5 {
                    let jointName = index == 1 ? "Neck" : (index == 2 ? "Right Shoulder" : "Left Shoulder")
                    print("🔍 \(jointName) mapped to: Model(\(mappedPoint.x), \(mappedPoint.y)), Pixel(\(pixelX), \(pixelY))")
                }
            } else {
                print("⚠️ Joint \(index) mapped outside normalized range: (\(mappedPoint.x), \(mappedPoint.y))")
            }
        } else if let point = point {
            print("ℹ️ Joint \(index) confidence too low: \(point.confidence) < \(confidenceThreshold)")
        }
    }
    
    // MARK: - Pose Buffer Management
    private func addToPoseBuffer(_ normalizedKeypoints: [[Float]], frameIndex: Int) {
        // Start collecting poses
        if !isCollectingPoses {
            isCollectingPoses = true
            frameCounter = frameIndex
            print("🔄 Started collecting poses at frame \(frameIndex)")
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
        print("🧠 Running action classifier with \(poseFrames.count) frames")
        
        guard let model = actionClassifierModel else {
            print("❌ Action Classifier model not loaded")
            return
        }
        
        do {
            // Create MLMultiArray with the exact shape expected by the model
            let inputShape = [NSNumber(value: 30), NSNumber(value: 3), NSNumber(value: 18)]
            guard let multiArray = try? MLMultiArray(shape: inputShape, dataType: .float32) else {
                print("❌ Failed to create MLMultiArray with shape \(inputShape)")
                return
            }
            
            print("✅ Created MLMultiArray with shape \(inputShape)")
            
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
            
            print("🧠 Running model prediction with input shape: \(multiArray.shape)")
            
            // Run inference
            let outputFeatures = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: inputDict))
            print("✅ Model prediction completed")
            
            // Extract prediction
            guard let labelOutput = outputFeatures.featureValue(for: "label")?.stringValue else {
                print("❌ Could not extract label from model output")
                return
            }
            
            print("🏷️ Predicted label: \(labelOutput)")
            
            var confidence: Float = 0.0
            if let probsOutput = outputFeatures.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: NSNumber] {
                // Print all probabilities for debugging
                print("📊 All class probabilities:")
                for (label, prob) in probsOutput {
                    print("\(label): \(prob.floatValue)")
                }
                
                confidence = probsOutput[labelOutput]?.floatValue ?? 0.0
                print("📊 Confidence for \(labelOutput): \(confidence)")
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
            } else {
                print("⚠️ Prediction confidence too low (\(confidence)), not updating UI")
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
