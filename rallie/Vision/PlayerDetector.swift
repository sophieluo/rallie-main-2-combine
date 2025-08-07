//
//  PlayerDetector.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import Vision
import UIKit

class PlayerDetector: ObservableObject {
    @Published var footPositionInImage: CGPoint? = nil
    @Published var boundingBox: CGRect? = nil
    @Published var centrePointInPixels: CGPoint? = nil
    
    private let sequenceHandler = VNSequenceRequestHandler()
    
    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer, completion: @escaping (VNHumanBodyPoseObservation?) -> Void = { _ in }) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        
        // Get screen size for coordinate conversion
        let screenSize = UIScreen.main.bounds.size
        
        // Create a new request for this specific call that includes the completion handler
        let poseRequest = VNDetectHumanBodyPoseRequest { (request: VNRequest, error: Error?) in
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                DispatchQueue.main.async { [weak self] in
                    self?.footPositionInImage = nil
                    self?.boundingBox = nil
                }
                print("👤 No person detected")
                completion(nil)
                return
            }
            
            print("👤 Person detected")
            
            // For back-facing detection, focus on these more reliable points
            let confidenceThreshold: CGFloat = 0.5  // Consider making this adjustable
            
            if let recognizedPoints = try? observation.recognizedPoints(.all) {
                // First check if we have at least one foot with good confidence
                let rightFoot = CGFloat(recognizedPoints[.rightAnkle]?.confidence ?? 0)
                let leftFoot = CGFloat(recognizedPoints[.leftAnkle]?.confidence ?? 0)
                
                // Use the most confident foot for position
                if rightFoot > confidenceThreshold || leftFoot > confidenceThreshold {
                    let bestFoot = rightFoot > leftFoot ? recognizedPoints[.rightAnkle] : 
                                                         recognizedPoints[.leftAnkle]
                    if let footPoint = bestFoot {
                        // Convert Vision coordinates (0-1) to pixel coordinates
                        let anklePosition = CGPoint(x: footPoint.location.x * screenSize.width,
                                                    y: (1 - footPoint.location.y) * screenSize.height)
                        
                        print("👣 Best foot position - raw: \(footPoint.location), transformed: \(anklePosition), confidence: \(footPoint.confidence)")
                        
                        DispatchQueue.main.async { [weak self] in
                            self?.footPositionInImage = anklePosition
                        }
                    }
                } else {
                    print("🦶 No feet detected with sufficient confidence")
                    DispatchQueue.main.async { [weak self] in
                        self?.footPositionInImage = nil
                    }
                }
            }
            
            // Pass the observation to the completion handler
            completion(observation)
        }
        
        do {
            try handler.perform([poseRequest])
        } catch {
            print("❌ Vision error: \(error)")
            completion(nil)
        }
    }
}
