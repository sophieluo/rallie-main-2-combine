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
                        
                        // ===== SERVICE LINE CALCULATION =====
                        if p.count >= 7 {
                            // STEP 1: Calculate slopes of the upper line (net) and lower line (baseline)
                            let upperLine = (p[0], p[1])  // (Top left, Top right)
                            let lowerLine = (p[2], p[3])  // (Bottom left, Bottom right)
                            
                            // Calculate slope of upper line (s1)
                            let s1_dx = upperLine.1.x - upperLine.0.x
                            let s1_dy = upperLine.1.y - upperLine.0.y
                            let s1 = s1_dy / s1_dx  // Slope of upper line (net)
                            
                            // Calculate slope of lower line (s2)
                            let s2_dx = lowerLine.1.x - lowerLine.0.x
                            let s2_dy = lowerLine.1.y - lowerLine.0.y
                            let s2 = s2_dy / s2_dx  // Slope of lower line (baseline)
                            
                            // STEP 2: Calculate the weighted average slope for the service line
                            // Using 0.55 * s1 + 0.45 * s2 as specified
                            let serviceLineSlope = 0.55 * s1 + 0.45 * s2
                            
                            // STEP 3: Calculate the equation of the service line passing through T-point
                            let tPoint = p[6]  // T-point
                            // y - y1 = m(x - x1) => y = m(x - x1) + y1 => y = mx - mx1 + y1
                            let serviceLineIntercept = tPoint.y - serviceLineSlope * tPoint.x
                            // Service line equation: y = serviceLineSlope * x + serviceLineIntercept
                            
                            // STEP 4: Calculate the left sideline equation
                            let leftSideline = (p[0], p[2])  // (Top left, Bottom left)
                            let leftSidelineSlope = (leftSideline.1.y - leftSideline.0.y) / (leftSideline.1.x - leftSideline.0.x)
                            let leftSidelineIntercept = leftSideline.0.y - leftSidelineSlope * leftSideline.0.x
                            // Left sideline equation: y = leftSidelineSlope * x + leftSidelineIntercept
                            
                            // STEP 5: Calculate the right sideline equation
                            let rightSideline = (p[1], p[3])  // (Top right, Bottom right)
                            let rightSidelineSlope = (rightSideline.1.y - rightSideline.0.y) / (rightSideline.1.x - rightSideline.0.x)
                            let rightSidelineIntercept = rightSideline.0.y - rightSidelineSlope * rightSideline.0.x
                            // Right sideline equation: y = rightSidelineSlope * x + rightSidelineIntercept
                            
                            // STEP 6: Calculate intersection of service line with left sideline
                            // At intersection: serviceLineSlope * x + serviceLineIntercept = leftSidelineSlope * x + leftSidelineIntercept
                            // => (serviceLineSlope - leftSidelineSlope) * x = leftSidelineIntercept - serviceLineIntercept
                            // => x = (leftSidelineIntercept - serviceLineIntercept) / (serviceLineSlope - leftSidelineSlope)
                            let leftIntersectionX = (leftSidelineIntercept - serviceLineIntercept) / (serviceLineSlope - leftSidelineSlope)
                            let leftIntersectionY = serviceLineSlope * leftIntersectionX + serviceLineIntercept
                            let leftServicePoint = CGPoint(x: leftIntersectionX, y: leftIntersectionY)
                            
                            // STEP 7: Calculate intersection of service line with right sideline
                            let rightIntersectionX = (rightSidelineIntercept - serviceLineIntercept) / (serviceLineSlope - rightSidelineSlope)
                            let rightIntersectionY = serviceLineSlope * rightIntersectionX + serviceLineIntercept
                            let rightServicePoint = CGPoint(x: rightIntersectionX, y: rightIntersectionY)
                            
                            // STEP 8: Draw the service line
                            path.move(to: leftServicePoint)
                            path.addLine(to: rightServicePoint)
                            
                            // ===== CENTER LINE CALCULATION =====
                            // STEP 9: Calculate the average slope of the two sidelines for the center line
                            let centerLineSlope = (leftSidelineSlope + rightSidelineSlope) / 2
                            
                            // STEP 10: Calculate the equation of the center line passing through T-point
                            let centerLineIntercept = tPoint.y - centerLineSlope * tPoint.x
                            // Center line equation: y = centerLineSlope * x + centerLineIntercept
                            
                            // STEP 11: Calculate intersection of center line with net (upper line)
                            // At intersection: centerLineSlope * x + centerLineIntercept = s1 * x + upperLineIntercept
                            let upperLineIntercept = upperLine.0.y - s1 * upperLine.0.x
                            let netIntersectionX = (upperLineIntercept - centerLineIntercept) / (centerLineSlope - s1)
                            let netIntersectionY = centerLineSlope * netIntersectionX + centerLineIntercept
                            let netCenterPoint = CGPoint(x: netIntersectionX, y: netIntersectionY)
                            
                            // STEP 12: Calculate intersection of center line with baseline (lower line)
                            let lowerLineIntercept = lowerLine.0.y - s2 * lowerLine.0.x
                            let baselineIntersectionX = (lowerLineIntercept - centerLineIntercept) / (centerLineSlope - s2)
                            let baselineIntersectionY = centerLineSlope * baselineIntersectionX + centerLineIntercept
                            let baselineCenterPoint = CGPoint(x: baselineIntersectionX, y: baselineIntersectionY)
                            
                            // STEP 13: Draw the center line from net to baseline
                            path.move(to: netCenterPoint)
                            path.addLine(to: baselineCenterPoint)
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
