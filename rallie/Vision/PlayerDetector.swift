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
    private lazy var request: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest { [weak self] (request: VNRequest, error: Error?) in
            guard let self = self,
                  let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                DispatchQueue.main.async {
                    self?.footPositionInImage = nil
                    self?.boundingBox = nil
                }
                print("👤 No person detected")
                return
            }
            
            print("👤123")
            
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
                        let imageWidth = UIScreen.main.bounds.width
                        let imageHeight = UIScreen.main.bounds.height
                        let anklePosition = CGPoint(x: footPoint.location.x * imageWidth,
                                                    y: (1 - footPoint.location.y) * imageHeight)
                        
                        print("👣 Best foot position - raw: \(footPoint.location), transformed: \(anklePosition), confidence: \(footPoint.confidence)")
                        
                        DispatchQueue.main.async {
                            self.footPositionInImage = anklePosition
                        }
                    }
                } else {
                    print("🦶 No feet detected with sufficient confidence")
                    DispatchQueue.main.async {
                        self.footPositionInImage = nil
                    }
                }
            }
        }
        return request
    }()
    
    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        do {
            try handler.perform([request])
        } catch {
            print("❌ Vision error: \(error)")
        }
    }
}
