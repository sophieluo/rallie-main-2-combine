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
        (1, 2),   // neck to right shoulder
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
                    Path { path in
                        path.move(to: scalePoint(start))
                        path.addLine(to: scalePoint(end))
                    }
                    .stroke(Color.green, lineWidth: connectionLineWidth)
                }
            }
            
            // Draw joints
            ForEach(0..<joints.count, id: \.self) { index in
                if let point = joints[index] {
                    Circle()
                        .fill(getJointColor(for: index))
                        .frame(width: jointRadius * 2, height: jointRadius * 2)
                        .position(scalePoint(point))
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
}
