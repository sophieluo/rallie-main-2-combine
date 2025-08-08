import SwiftUI
import Vision

struct JointsView: View {
    var joints: [CGPoint?]
    var originalSize: CGSize
    var viewSize: CGSize
    
    private let jointRadius: CGFloat = 5
    private let connectionLineWidth: CGFloat = 2
    
    // Define connections between joints for drawing lines
    private let connections: [(Int, Int)] = [
        (0, 1),   // nose to neck
        (1, 2),   // neck to right shoulder - temporarily disabled due to mapping issue
        (1, 5),   // neck to left shoulder
        (2, 3),   // right shoulder to right elbow
        (3, 4),   // right elbow to right wrist
        (5, 6),   // left shoulder to left elbow
        (6, 7),   // left elbow to left wrist
        (1, 8),   // neck to mid hip
        (8, 9),   // mid hip to right hip
        (8, 12),  // mid hip to left hip
        (9, 10),  // right hip to right knee
        (10, 11), // right knee to right ankle
        (12, 13), // left hip to left knee
        (13, 14)  // left knee to left ankle
    ]
    
    var body: some View {
        ZStack {
            // Draw connections between joints
            ForEach(connections, id: \.0) { connection in
                if let start = joints[connection.0],
                   let end = joints[connection.1] {
                    let startPoint = scalePoint(start)
                    let endPoint = scalePoint(end)
                    let lineLength = sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2))
                    
                    Path { path in
                        path.move(to: scalePoint(start))
                        path.addLine(to: scalePoint(end))
                    }
                    .stroke(Color.green, lineWidth: connectionLineWidth)
                    .background(
                        // This is a hack to print line lengths without using print() in the view body
                        Color.clear
                            .onAppear {
                                let connectionName = getConnectionName(connection)
                                print("📏 Line length for connection (\(connection.0), \(connection.1)) - \(connectionName): \(lineLength) pixels")
                                
                                if lineLength > 200 {
                                    print("⚠️ UNUSUALLY LONG LINE: Connection (\(connection.0), \(connection.1)) - \(connectionName) length: \(lineLength) pixels")
                                }
                            }
                    )
                }
            }
            
            // Draw joints
            ForEach(0..<joints.count, id: \.self) { index in
                if let point = joints[index], isValidPoint(point) {
                    Circle()
                        .fill(getJointColor(for: index))
                        .frame(width: jointRadius * 2, height: jointRadius * 2)
                        .position(scalePoint(point))
                }
            }
        }
        .onAppear {
            debugJointPositions()
            calculateLineDistances()
        }
    }
    
    // Update joints for visualization
    mutating func updateJoints(_ newJoints: [CGPoint]) {
        self.joints = newJoints.map { $0 != .zero ? $0 : nil }
        
        // Debug: Print joint positions and identify potential stray joints
        print("🔍 JOINT POSITIONS UPDATE:")
        for (index, joint) in newJoints.enumerated() {
            if joint != .zero {
                print("Joint \(index): (\(Int(joint.x)), \(Int(joint.y)))")
                
                // Check for potentially stray joints (far from center)
                let centerX = originalSize.width / 2
                let centerY = originalSize.height / 2
                let distanceFromCenter = sqrt(pow(joint.x - centerX, 2) + pow(joint.y - centerY, 2))
                let maxNormalDistance = max(originalSize.width, originalSize.height) * 0.6
                
                if distanceFromCenter > maxNormalDistance {
                    print("⚠️ POTENTIAL STRAY JOINT: Joint \(index) is far from center: \(Int(distanceFromCenter)) pixels")
                }
            }
        }
        
        // Print distances between key joints
        let keyConnections = [(1, 2, "Neck to Right Shoulder"), (1, 5, "Neck to Left Shoulder")]
        for (i, j, name) in keyConnections {
            if i < newJoints.count && j < newJoints.count && newJoints[i] != .zero && newJoints[j] != .zero {
                let distance = sqrt(pow(newJoints[j].x - newJoints[i].x, 2) + pow(newJoints[j].y - newJoints[i].y, 2))
                print("📏 \(name): \(Int(distance)) pixels")
                
                if distance > 200 {
                    print("⚠️ UNUSUALLY LONG CONNECTION: \(name): \(Int(distance)) pixels")
                }
            }
        }
    }
    
    // Separate method for debugging joint positions and connections
    private func debugJointPositions() {
        // Print all joint positions
        print("JOINT_POSITIONS:")
        for (index, point) in joints.enumerated() {
            if let point = point {
                print("Joint \(index): \(point) → \(scalePoint(point))")
            }
        }
        
        // Calculate distances between all joints
        print("JOINT_DISTANCES:")
        for i in 0..<joints.count {
            if let point1 = joints[i] {
                for j in (i+1)..<joints.count {
                    if let point2 = joints[j] {
                        let distance = sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
                        print("Distance between joints \(i) and \(j): \(distance)")
                        
                        // Flag unusually large distances
                        if distance > originalSize.width / 2 {
                            print("⚠️ LARGE_DISTANCE_WARNING: Joints \(i) and \(j) are unusually far apart: \(distance)")
                        }
                    }
                }
            }
        }
    }
    
    // Calculate and print line distances
    private func calculateLineDistances() {
        print("LINE_LENGTHS:")
        for connection in connections {
            if let start = joints[connection.0],
               let end = joints[connection.1] {
                let startPoint = scalePoint(start)
                let endPoint = scalePoint(end)
                let lineLength = sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2))
                
                let connectionName = getConnectionName(connection)
                print("📏 Line length for connection (\(connection.0), \(connection.1)) - \(connectionName): \(lineLength) pixels")
                
                // Flag unusually long lines
                if lineLength > 200 {
                    print("⚠️ UNUSUALLY LONG LINE: Connection (\(connection.0), \(connection.1)) - \(connectionName) length: \(lineLength) pixels")
                }
            }
        }
    }
    
    // Scale point from original image coordinates to view coordinates
    private func scalePoint(_ point: CGPoint) -> CGPoint {
        let scaleX = viewSize.width / originalSize.width
        let scaleY = viewSize.height / originalSize.height
        
        return CGPoint(
            x: point.x * scaleX,
            y: point.y * scaleY
        )
    }
    
    // Get color for different joint types
    private func getJointColor(for index: Int) -> Color {
        switch index {
        case 0:  // nose
            return .yellow
        case 1:  // neck
            return .orange
        case 2...7:  // shoulders, elbows, wrists
            return .red
        case 8...14: // hips, knees, ankles
            return .blue
        case 15...17: // eyes, ears
            return .purple
        default:
            return .green
        }
    }
    
    // Check if a point is valid for display (not zero or near-zero)
    private func isValidPoint(_ point: CGPoint) -> Bool {
        // Filter out points that are at (0,0) or very close to it
        // Also filter out any points with negative coordinates or outside the frame
        let minThreshold: CGFloat = 1.0  // Increased threshold
        
        // Basic boundary check
        guard point.x >= minThreshold && 
              point.y >= minThreshold && 
              point.x <= originalSize.width - minThreshold && 
              point.y <= originalSize.height - minThreshold else {
            return false
        }
        
        // Check for outliers - points that are too far from the center of the frame
        // This helps catch points that are technically within bounds but clearly wrong
        let centerX = originalSize.width / 2
        let centerY = originalSize.height / 2
        let maxDistanceFromCenter = max(originalSize.width, originalSize.height) * 0.75
        
        let distanceFromCenter = sqrt(pow(point.x - centerX, 2) + pow(point.y - centerY, 2))
        return distanceFromCenter <= maxDistanceFromCenter
    }
    
    // Get connection name for debugging
    private func getConnectionName(_ connection: (Int, Int)) -> String {
        switch connection {
        case (0, 1): return "Nose to Neck"
        case (1, 2): return "Neck to Right Shoulder"
        case (1, 5): return "Neck to Left Shoulder"
        case (2, 3): return "Right Shoulder to Right Elbow"
        case (3, 4): return "Right Elbow to Right Wrist"
        case (5, 6): return "Left Shoulder to Left Elbow"
        case (6, 7): return "Left Elbow to Left Wrist"
        case (1, 8): return "Neck to Mid Hip"
        case (8, 9): return "Mid Hip to Right Hip"
        case (8, 12): return "Mid Hip to Left Hip"
        case (9, 10): return "Right Hip to Right Knee"
        case (10, 11): return "Right Knee to Right Ankle"
        case (12, 13): return "Left Hip to Left Knee"
        case (13, 14): return "Left Knee to Left Ankle"
        default: return "Unknown Connection"
        }
    }
}
