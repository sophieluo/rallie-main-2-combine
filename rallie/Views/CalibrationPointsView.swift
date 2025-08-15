import SwiftUI
import UIKit

struct CalibrationPointsView: View {
    @ObservedObject var cameraController: CameraController

    var body: some View {
        LandscapeContainerView {
            GeometryReader { geometry in
                ZStack {
                    // Draw court lines using user tapped points
                    if cameraController.userTappedPoints.count >= 5 {
                        // Court boundary
                        Path { path in
                            let p = cameraController.userTappedPoints
                            
                            // Draw the main court outline using user tapped points
                            // For a tennis court, we use the 5 user-tapped points to form the court outline
                            // Point 0: Net left corner
                            // Point 1: Net right corner
                            // Point 2: Baseline left corner
                            // Point 3: Baseline right corner
                            // Point 4: Center mark (T-point)
                            
                            // Draw the main court outline
                            if p.count >= 4 {
                                path.move(to: p[0])    // Net left corner
                                path.addLine(to: p[1]) // Net right corner
                                path.addLine(to: p[3]) // Baseline right corner
                                path.addLine(to: p[2]) // Baseline left corner
                                path.closeSubpath()
                            }
                            
                            // Draw the center line if we have the T-point
                            if p.count >= 5 {
                                // Calculate center of net (midpoint between points 0 and 1)
                                let centerNet = CGPoint(
                                    x: (p[0].x + p[1].x) / 2,
                                    y: (p[0].y + p[1].y) / 2
                                )
                                
                                // Draw center line from net to T-point
                                path.move(to: centerNet)
                                path.addLine(to: p[4]) // T-point
                            }
                        }
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    }
                    
                    // Only draw user tapped points (the ones the user directly tapped)
                    ForEach(0..<cameraController.userTappedPoints.count, id: \.self) { index in
                        let point = cameraController.userTappedPoints[index]
                        ZStack {
                            Circle()
                                .fill(getCalibrationPointColor(for: index))
                                .frame(width: 20, height: 20)
                            
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .position(x: point.x, y: point.y)
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
                                
                                // Save that calibration has been performed
                                UserDefaults.standard.set(true, forKey: cameraController.hasCalibrationBeenPerformedKey)
                                cameraController.hasCalibrationBeenPerformedBefore = true
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
    
    // Helper function to get color for calibration points
    private func getCalibrationPointColor(for index: Int) -> Color {
        switch index {
        case 0, 1, 2, 3:
            return Color.red
        case 4:
            return Color.blue
        case 5, 6:
            return Color.green
        case 7:
            return Color.yellow
        default:
            return Color.white
        }
    }
}

// Custom landscape container view
struct LandscapeContainerView<Content: View>: UIViewControllerRepresentable {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let hostingController = CustomLandscapeHostingController(rootView: content())
        return hostingController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let hostingController = uiViewController as? CustomLandscapeHostingController<Content> {
            hostingController.rootView = content()
        }
    }
}

// Custom landscape hosting controller
class CustomLandscapeHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        forceLandscapeOrientation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        forceLandscapeOrientation()
    }
    
    private func forceLandscapeOrientation() {
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
}
