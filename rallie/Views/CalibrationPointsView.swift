import SwiftUI

struct CalibrationPointsView: View {
    @ObservedObject var cameraController: CameraController

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw court outline based on calibration points
                if cameraController.calibrationPoints.count >= 8 {
                    // Court boundary
                    Path { path in
                        let p = cameraController.calibrationPoints
                        
                        // Main court outline - using the correct point order with clear naming
                        // Point 0: Top-left corner (net, left sideline)
                        // Point 1: Top-right corner (net, right sideline)
                        // Point 2: Bottom-left corner (baseline, left sideline)
                        // Point 3: Bottom-right corner (baseline, right sideline)
                        // Point 4: T-point (center of service line)
                        // Point 5: Left service line intersection
                        // Point 6: Right service line intersection
                        // Point 7: Center net point
                        
                        // Draw the main court outline
                        path.move(to: p[0])    // Point 0: Top-left corner (net)
                        path.addLine(to: p[1]) // Point 1: Top-right corner (net)
                        path.addLine(to: p[3]) // Point 3: Bottom-right corner (baseline)
                        path.addLine(to: p[2]) // Point 2: Bottom-left corner (baseline)
                        path.closeSubpath()
                        
                        // Draw the service line
                        path.move(to: p[5])    // Point 5: Left service line intersection
                        path.addLine(to: p[6]) // Point 6: Right service line intersection
                        
                        // Draw the center line from net to T-point
                        path.move(to: p[7])    // Point 7: Center net point
                        path.addLine(to: p[4]) // Point 4: T-point (center service)
                    }
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                }
                
                // Draw calibration guidance UI
                VStack(spacing: 20) {
                    // Step indicator
                    Text("Step \(min(cameraController.calibrationStep + 1, 5)) of 5")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .padding(.top, 20)
                    
                    // Instruction text
                    Text(cameraController.calibrationInstructions)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    
                    // Visual indicator of where to tap
                    getTargetIndicator(for: cameraController.calibrationStep)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                        .opacity(0.8)
                    
                    Spacer()
                    
                    // Only show the Complete button when all 5 points have been tapped
                    if cameraController.calibrationStep >= 5 {
                        Button(action: {
                            cameraController.computeHomographyFromCalibrationPoints()
                            cameraController.isCalibrationMode = false
                        }) {
                            Text("Complete Calibration")
                                .font(.headline)
                                .padding()
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    // Helper function to get appropriate visual indicator for each calibration step
    private func getTargetIndicator(for step: Int) -> some View {
        switch step {
        case 0: // Top-left corner (net, left sideline)
            return AnyView(
                Image(systemName: "arrow.up.left.circle")
                    .font(.system(size: 40))
            )
        case 1: // Top-right corner (net, right sideline)
            return AnyView(
                Image(systemName: "arrow.up.right.circle")
                    .font(.system(size: 40))
            )
        case 2: // Bottom-left corner (baseline, left sideline)
            return AnyView(
                Image(systemName: "arrow.down.left.circle")
                    .font(.system(size: 40))
            )
        case 3: // Bottom-right corner (baseline, right sideline)
            return AnyView(
                Image(systemName: "arrow.down.right.circle")
                    .font(.system(size: 40))
            )
        case 4: // T-point (center of service line)
            return AnyView(
                Image(systemName: "plus.circle")
                    .font(.system(size: 40))
            )
        default:
            return AnyView(
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40))
            )
        }
    }
}
