//
//  ObjectDetector.swift
//  rallie
//
//


import Foundation
import Vision
import CoreML
import SwiftUI

class ObjectDetector: ObservableObject {
    private let visionModel: VNCoreMLModel

    @Published var centrePointPositionInImage: CGPoint? = nil
    @Published var bottomcentrePointPositionInImage: CGPoint? = nil
    @Published var centrePointInPixels: CGPoint? = nil
    @Published var bottomLeftPixel: CGPoint? = nil

    init() {
        guard let coreMLModel = try? Tennis30epochsCompleteTrainYolov5s(configuration: MLModelConfiguration()).model,
              let visionModel = try? VNCoreMLModel(for: coreMLModel) else {
            fatalError("Failed to load CoreML model")
        }
        self.visionModel = visionModel
    }

    func detectObjects(in pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]) -> Void) {
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                completion([])
                return
            }

            let screenSize = UIScreen.main.bounds.size
            let screenWidth = screenSize.width
            let screenHeight = screenSize.height

            let detected = results.compactMap { obs -> DetectedObject? in
                let confidence = obs.confidence
                guard confidence >= 0.45 else { return nil }

                let label = obs.labels.first?.identifier ?? "Object"
                let boundingBox = obs.boundingBox

                // Convert normalized rect to screen space
                let x = boundingBox.origin.x * screenWidth
                let y = (1.0 - boundingBox.origin.y - boundingBox.height) * screenHeight
                let width = boundingBox.width * screenWidth
                let height = boundingBox.height * screenHeight

                var boxRect = CGRect(x: x, y: y, width: width, height: height)

                // ✅ Expand box height downward to better include feet
                let expandFactor: CGFloat = 1.2
                let newHeight = boxRect.height * expandFactor
                let heightIncrease = newHeight - boxRect.height
                boxRect = CGRect(
                    x: boxRect.origin.x,
                    y: boxRect.origin.y - heightIncrease * 0.31, // Push down more than up
                    width: boxRect.width,
                    height: newHeight
                )

                // Ensure the box stays within screen bounds
                boxRect = boxRect.intersection(CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))

                let pixelCenter = CGPoint(x: boxRect.midX, y: boxRect.midY)
                let bottomLeft = CGPoint(x: boxRect.minX, y: boxRect.maxY)
                let bottomCenter = CGPoint(x: boxRect.midX, y: boxRect.maxY)

                self.bottomcentrePointPositionInImage = bottomCenter
                self.centrePointPositionInImage = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
                self.centrePointInPixels = pixelCenter
                self.bottomLeftPixel = bottomLeft

                return DetectedObject(
                    label: label,
                    confidence: confidence,
                    rect: CGRect(
                        x: boxRect.origin.x / screenWidth,
                        y: boxRect.origin.y / screenHeight,
                        width: boxRect.width / screenWidth,
                        height: boxRect.height / screenHeight
                    ),
                    pixelCenter: pixelCenter,
                    bottomLeftPixel: bottomLeft,
                    bottomCenterPixel: bottomCenter
                )
            }

            completion(detected)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Vision error: \(error)")
                completion([])
            }
        }
    }

}


struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: VNConfidence
    let rect: CGRect           // Normalized
    let pixelCenter: CGPoint
    let bottomLeftPixel: CGPoint
    let bottomCenterPixel: CGPoint
}
