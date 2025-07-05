import SwiftUI

struct CalibrationPointsView: View {
    @ObservedObject var cameraController: CameraController

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw court outline based on calibration points
                if cameraController.calibrationPoints.count >= 4 {
                    // Court boundary
                    Path { path in
                        let p = cameraController.calibrationPoints
                        
                        // Main court outline - using the correct point order
                        path.move(to: p[0])  // Top left (net)
                        path.addLine(to: p[1])  // Top right (net)
                        path.addLine(to: p[3])  // Bottom right (baseline)
                        path.addLine(to: p[2])  // Bottom left (baseline)
                        path.closeSubpath()
                        
                        // Service line - horizontal line passing through T-point
                        if p.count >= 7 {
                            path.move(to: p[4])  // Left service
                            path.addLine(to: p[5])  // Right service
                        }
                        
                        // Center line - vertical line from net to baseline
                        if p.count >= 8 {
                            // Draw from net center to baseline using the x-coordinate of the T-point
                            path.move(to: p[7])  // Net center
                            
                            // Extend the line through the T-point all the way to the baseline
                            let baselineY = (p[2].y + p[3].y) / 2  // Average Y of baseline points
                            path.addLine(to: CGPoint(x: p[6].x, y: baselineY))
                        }
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
