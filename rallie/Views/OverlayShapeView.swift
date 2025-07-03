//
//  OverlayShapeView.swift
//  rallie
//
//  Created by Xiexiao_Luo on 4/12/25.
//

//import SwiftUI
//
//struct OverlayShapeView: View {
//    var isActivated: Bool
//    @ObservedObject var cameraController: CameraController
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // Draw court lines
//                Path { path in
//                    for line in cameraController.projectedCourtLines {
//                        path.move(to: line.start)
//                        path.addLine(to: line.end)
//                    }
//                }
//                .stroke(Color.red.opacity(isActivated ? 1.0 : 0.3), lineWidth: 2)
//
//                // Draw bounding boxes
//                ForEach(cameraController.detectedObjects) { object in
//                    let objectView = createObjectBoxView(for: object, in: geometry.size)
//                    objectView
//                }
//            }
//        }
//        .ignoresSafeArea()
//    }
//
//    // MARK: - Extracted Function to Build Each Object Box
//    private func createObjectBoxView(for object: DetectedObject, in containerSize: CGSize) -> some View {
//        let normalizedRect = object.rect
//
//        // Padding percentages
//        let paddingWidth: CGFloat = 0.01
//        let paddingHeight: CGFloat = 0.075
//
//        // Expand the rect
//        var expandedRect = normalizedRect.insetBy(
//            dx: -paddingWidth,
//            dy: -paddingHeight
//        )
//
//        // Clamp to 0...1
//        expandedRect.origin.x = max(0, expandedRect.origin.x)
//        expandedRect.origin.y = max(0, expandedRect.origin.y)
//        expandedRect.size.width = min(1 - expandedRect.origin.x, expandedRect.size.width)
//        expandedRect.size.height = min(1 - expandedRect.origin.y, expandedRect.size.height)
//
//        // Convert to screen-space
//        let box = CGRect(
//            x: expandedRect.origin.x * containerSize.width,
//            y: expandedRect.origin.y * containerSize.height,
//            width: expandedRect.size.width * containerSize.width,
//            height: expandedRect.size.height * containerSize.height
//        )
//
//        return ZStack {
//            // Bounding box
//            Rectangle()
//                .stroke(Color.green, lineWidth: 2)
//                .frame(width: box.width, height: box.height)
//                .position(x: box.midX, y: box.midY)
//
//            // Red marker
//            Circle()
//                .fill(Color.red)
//                .frame(width: 10, height: 10)
//                .overlay(Circle().stroke(Color.white, lineWidth: 1))
//                .position(x: box.midX, y: box.maxY - 5)
//        }
//    }
//}

import SwiftUI

struct OverlayShapeView: View {
    var isActivated: Bool
    @ObservedObject var cameraController: CameraController

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw court lines
                Path { path in
                    for line in cameraController.projectedCourtLines {
                        path.move(to: line.start)
                        path.addLine(to: line.end)
                    }
                }
                .stroke(Color.red.opacity(isActivated ? 1.0 : 0.3), lineWidth: 2)

                // Draw detected object bounding boxes
                ForEach(cameraController.detectedObjects) { object in
                    let rect = object.rect
                    let box = CGRect(
                        x: rect.origin.x * geometry.size.width,
                        y: rect.origin.y * geometry.size.height,
                        width: rect.size.width * geometry.size.width,
                        height: rect.size.height * geometry.size.height
                    )
//
//                    // Bounding box
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)

                    // Label
//                    Text("\(object.label) \(Int(object.confidence * 100))%")
//                        .font(.caption2)
//                        .padding(4)
//                        .background(Color.black.opacity(0.7))
//                        .foregroundColor(.white)
//                        .position(x: box.minX + 40, y: box.minY - 10)

                    // Optional center dot
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .position(x: box.midX, y: box.maxY - 5)
                  
                }
            }
        }
        .ignoresSafeArea()
    }
}
