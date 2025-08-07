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
        
        // Map Vision keypoints to our format
        if let nose = recognizedPoints[.nose], nose.confidence > 0.1 {
            keypoints[0] = CGPoint(x: nose.location.x * originalSize.width, y: nose.location.y * originalSize.height)
        }
        
        if let neck = recognizedPoints[.neck], neck.confidence > 0.1 {
            keypoints[1] = CGPoint(x: neck.location.x * originalSize.width, y: neck.location.y * originalSize.height)
        }
        
        // Right arm
        if let rightShoulder = recognizedPoints[.rightShoulder], rightShoulder.confidence > 0.1 {
            keypoints[2] = CGPoint(x: rightShoulder.location.x * originalSize.width, y: rightShoulder.location.y * originalSize.height)
        }
        
        if let rightElbow = recognizedPoints[.rightElbow], rightElbow.confidence > 0.1 {
            keypoints[3] = CGPoint(x: rightElbow.location.x * originalSize.width, y: rightElbow.location.y * originalSize.height)
        }
        
        if let rightWrist = recognizedPoints[.rightWrist], rightWrist.confidence > 0.1 {
            keypoints[4] = CGPoint(x: rightWrist.location.x * originalSize.width, y: rightWrist.location.y * originalSize.height)
        }
        
        // Left arm
        if let leftShoulder = recognizedPoints[.leftShoulder], leftShoulder.confidence > 0.1 {
            keypoints[5] = CGPoint(x: leftShoulder.location.x * originalSize.width, y: leftShoulder.location.y * originalSize.height)
        }
        
        if let leftElbow = recognizedPoints[.leftElbow], leftElbow.confidence > 0.1 {
            keypoints[6] = CGPoint(x: leftElbow.location.x * originalSize.width, y: leftElbow.location.y * originalSize.height)
        }
        
        if let leftWrist = recognizedPoints[.leftWrist], leftWrist.confidence > 0.1 {
            keypoints[7] = CGPoint(x: leftWrist.location.x * originalSize.width, y: leftWrist.location.y * originalSize.height)
        }
        
        // Update the last detected joints for visualization
        lastDetectedJoints = keypoints
        
        // Convert optional points to array of points, using (0,0) for missing points
        let points = keypoints.map { point -> CGPoint in
            return point ?? CGPoint.zero
        }
        
        // Normalize keypoints to 1080x1920 canvas
        let normalizedKeypoints = normalizeKeypoints(points, boundingBox: boundingBox)
        
        // Add to pose buffer
        addToPoseBuffer(normalizedKeypoints, frameIndex: frameIndex)
    }
    
    // MARK: - Keypoint Normalization
    private func normalizeKeypoints(_ keypoints: [CGPoint], boundingBox: CGRect) -> [[Float]] {
        // Create result array: [3][18] - [x/y/conf][joint]
        var result = Array(repeating: Array(repeating: Float(0), count: 18), count: 3)
        
        // Reference canvas size for normalization (1080x1920)
        let referenceWidth: CGFloat = 1080
        let referenceHeight: CGFloat = 1920
        
        // For each keypoint
        for i in 0..<min(18, keypoints.count) {
            let point = keypoints[i]
            
            // Skip points at (0,0) - they're missing
            if point.x == 0 && point.y == 0 {
                result[0][i] = 0
                result[1][i] = 0
                result[2][i] = 0
            } else {
                // Normalize to reference canvas (1080x1920)
                result[0][i] = Float(point.x / referenceWidth)
                result[1][i] = Float(point.y / referenceHeight)
                result[2][i] = 1.0 // Confidence is 1.0 for detected points
            }
        }
        
        return result
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
            // Run classifier on the last 30 frames
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
                for coordIdx in 0..<3 { // x, y, confidence
                    for jointIdx in 0..<18 {
                        // Calculate the index in the multi-array
                        let index = [NSNumber(value: frameIdx), NSNumber(value: coordIdx), NSNumber(value: jointIdx)]
                        let value = poseFrames[frameIdx][coordIdx][jointIdx]
                        // Use subscript syntax instead of setValue
                        multiArray[index] = NSNumber(value: value)
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
                confidence = probsOutput[labelOutput]?.floatValue ?? 0.0
                print("📊 Confidence: \(confidence)")
            }
            
            // Store prediction
            let prediction = (startFrame: startFrame, endFrame: endFrame, label: labelOutput, confidence: confidence)
            predictions.append(prediction)
            
            // Update UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentAction = labelOutput
                self.actionConfidence = confidence
                
                // Notify observers
                self.objectWillChange.send()
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
    }
}
