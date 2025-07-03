//
//  CalibrationPointsView.swift
//  rallie
//
//  Created by Xiexiao_Luo on 5/10/25.
//

//import SwiftUI
//
//struct CalibrationPointsView: View {
//    @ObservedObject var cameraController: CameraController
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // Flip Y axis for display
//                let flipY: (CGPoint) -> CGPoint = { point in
//                    CGPoint(x: point.x, y: geometry.size.height - point.y)
//                }
//
//                // Court + service lines
//                Path { path in
//                    if cameraController.calibrationPoints.count >= 4 {
//                        let p = cameraController.calibrationPoints
//                        let topLeft = flipY(p[0])
//                        let topRight = flipY(p[1])
//                        let bottomRight = flipY(p[2])
//                        let bottomLeft = flipY(p[3])
//
//                        // Outer boundary
//                        path.move(to: topLeft)
//                        path.addLine(to: topRight)
//                        path.addLine(to: bottomRight)
//                        path.addLine(to: bottomLeft)
//                        path.closeSubpath()
//
//                        // Midpoints for left and right sides (horizontal service line)
//                        let midLeft = midpoint(topLeft, bottomLeft)
//                        let midRight = midpoint(topRight, bottomRight)
//                        path.move(to: midLeft)
//                        path.addLine(to: midRight)
//
//                        // Center line — only on TOP HALF
//                        let serviceTop = midpoint(topLeft, topRight)
//                        let serviceBottom = midpoint(midLeft, midRight)
//                        path.move(to: serviceTop)
//                        path.addLine(to: serviceBottom)
//                    }
//                }
//                .stroke(Color.red.opacity(0.8), lineWidth: 2)
//
//
//
//                // Draggable 4 corners
//                ForEach(0..<min(4, cameraController.calibrationPoints.count), id: \.self) { i in
//                    DraggablePoint(
//                        position: Binding(
//                            get: { cameraController.calibrationPoints[i] },
//                            set: { cameraController.calibrationPoints[i] = $0 }
//                        ),
//                        color: pointColor(for: i),
//                        canvasHeight: geometry.size.height
//                    )
//                }
//            }
//        }
//        .ignoresSafeArea()
//    }
//
//    // Interpolates X at a given Y between two points (assumes line is not vertical)
//    private func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
//        CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
//    }
//
//    private func pointColor(for index: Int) -> Color {
//        let colors: [Color] = [.blue, .green, .yellow, .purple]
//        return colors[index % colors.count]
//    }
//}
//
//
//
//
//
//struct DraggablePoint: View {
//    @Binding var position: CGPoint
//    var color: Color
//    var canvasHeight: CGFloat
//
//    var body: some View {
//        Circle()
//            .fill(color)
//            .frame(width: 38, height: 38)
//            .opacity(0.7)
//            .position(x: position.x, y: canvasHeight - position.y)
//            .gesture(
//                DragGesture()
//                    .onChanged { value in
//                        position = CGPoint(x: value.location.x, y: canvasHeight - value.location.y)
//                    }
//            )
//    }
//}
import SwiftUI

struct CalibrationPointsView: View {
    @ObservedObject var cameraController: CameraController
    @State private var serviceLineOffset: CGFloat = 0.5 // Normalized Y between top and bottom

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let flipY: (CGPoint) -> CGPoint = { point in
                    CGPoint(x: point.x, y: geometry.size.height - point.y)
                }

                // Draw Court Path
                Path { path in
                    if cameraController.calibrationPoints.count >= 4 {
                        let p = cameraController.calibrationPoints
                        let topLeft = flipY(p[0])
                        let topRight = flipY(p[1])
                        let bottomRight = flipY(p[2])
                        let bottomLeft = flipY(p[3])

                        // Outer boundary
                        path.move(to: topLeft)
                        path.addLine(to: topRight)
                        path.addLine(to: bottomRight)
                        path.addLine(to: bottomLeft)
                        path.closeSubpath()

                        // Service line (horizontal)
                        let midLeft = CGPoint(
                            x: (topLeft.x + bottomLeft.x) / 2,
                            y: topLeft.y + (bottomLeft.y - topLeft.y) * serviceLineOffset
                        )
                        let midRight = CGPoint(
                            x: (topRight.x + bottomRight.x) / 2,
                            y: topRight.y + (bottomRight.y - topRight.y) * serviceLineOffset
                        )
                        path.move(to: midLeft)
                        path.addLine(to: midRight)

                        // Center line (vertical from top to service line)
                        let serviceTop = CGPoint(
                            x: (topLeft.x + topRight.x) / 2,
                            y: topLeft.y
                        )
                        let serviceBottom = CGPoint(
                            x: (bottomLeft.x + bottomRight.x) / 2,
                            y: midLeft.y
                        )
                        path.move(to: serviceTop)
                        path.addLine(to: serviceBottom)
                    }
                }
                .stroke(Color.red.opacity(0.8), lineWidth: 2)

                // Draggable center service control circle
                if cameraController.calibrationPoints.count >= 4 {
                    let p = cameraController.calibrationPoints
                    let topLeft = flipY(p[0])
                    let topRight = flipY(p[1])
                    let bottomLeft = flipY(p[3])
                    let bottomRight = flipY(p[2])

                    let midLeft = CGPoint(
                        x: (topLeft.x + bottomLeft.x) / 2,
                        y: topLeft.y + (bottomLeft.y - topLeft.y) * serviceLineOffset
                    )
                    let midRight = CGPoint(
                        x: (topRight.x + bottomRight.x) / 2,
                        y: topRight.y + (bottomRight.y - topRight.y) * serviceLineOffset
                    )

                    let center = CGPoint(
                        x: (midLeft.x + midRight.x) / 2,
                        y: (midLeft.y + midRight.y) / 2
                    )

                    Circle()
                        .fill(Color.orange)
                        .frame(width: 38, height: 38)
                        .position(center)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let topY = (topLeft.y + topRight.y) / 2
                                    let bottomY = (bottomLeft.y + bottomRight.y) / 2
                                    let clampedY = max(min(value.location.y, bottomY), topY)
                                    let normalized = (clampedY - topY) / (bottomY - topY)
                                    serviceLineOffset = normalized
                                }
                        )
                }

                // Draggable corner points
                ForEach(0..<min(4, cameraController.calibrationPoints.count), id: \.self) { i in
                    DraggablePoint(
                        position: Binding(
                            get: { cameraController.calibrationPoints[i] },
                            set: { cameraController.calibrationPoints[i] = $0 }
                        ),
                        color: pointColor(for: i),
                        canvasHeight: geometry.size.height
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    // Helper to color draggable points
    private func pointColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .yellow, .purple]
        return colors[index % colors.count]
    }
}

struct DraggablePoint: View {
    @Binding var position: CGPoint
    var color: Color
    var canvasHeight: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 38, height: 38)
            .opacity(0.7)
            .position(x: position.x, y: canvasHeight - position.y)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        position = CGPoint(x: value.location.x, y: canvasHeight - value.location.y)
                    }
            )
    }
}
