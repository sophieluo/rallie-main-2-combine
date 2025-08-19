import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    @ObservedObject var cameraController: CameraController
    @ObservedObject var bluetoothManager = BluetoothManager.shared
    @ObservedObject var logicManager = LogicManager.shared
    @Environment(\.dismiss) private var dismiss
    
    init(cameraController: CameraController) {
        _cameraController = ObservedObject(wrappedValue: cameraController)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
              CameraPreview()
            }
            .ignoresSafeArea()
            
            ZStack {
                // Transparent overlay to capture taps
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let tapPoint = value.location
                                
                                if cameraController.isCalibrationMode {
                                    print("📍 Tap location: \(tapPoint)")
                                    cameraController.handleCalibrationTap(at: tapPoint)
                                }
                            }
                    )

                // Only show user tapped points, not the calculated calibration points
                // User tapped points overlay (larger and more visible)
                ForEach(0..<cameraController.userTappedPoints.count, id: \.self) { index in
                    let point = cameraController.userTappedPoints[index]
                    ZStack {
                        // Outer glow for better visibility
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 30, height: 30)
                        
                        // Main colored circle
                        Circle()
                            .fill(getCalibrationPointColor(for: index))
                            .frame(width: 20, height: 20)
                        
                        // Label for the point
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .position(x: point.x, y: point.y)
                }
                
                // Court lines overlay
                Path { path in
                    for line in cameraController.projectedCourtLines {
                        path.move(to: line.start)
                        path.addLine(to: line.end)
                    }
                }
                .stroke(Color.green, lineWidth: 2)
                
                // Calibration or overlay UI
                if cameraController.isCalibrationMode {
                    // Use calibration UI as an overlay instead of a replacement view
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
                        getCalibrationTargetIndicator(for: cameraController.calibrationStep)
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
                } else {
                    OverlayShapeView(
                        isActivated: true, cameraController: cameraController
                    )
                }
                
                // Top UI elements
                VStack {
                    HStack {
                        // Top-left close button
                        Button(action: {
                            cameraController.stopSession()
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        // Mini court view in top-right
                        if !cameraController.isCalibrationMode {
                            MiniCourtView(playerPosition: cameraController.projectedPlayerPosition)
                                .frame(width: 140, height: 100)
                                .padding(.trailing, 10)
                        }
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
            // Apply 90-degree clockwise rotation to the entire UI container
//            .rotationEffect(.degrees(90))
            // Adjust frame to match rotated dimensions
//            .frame(width: geometry.size.height, height: geometry.size.width)
            // Center in the view
//            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .ignoresSafeArea(.all)
        .alert("Would you like to recalibrate the court?", isPresented: $cameraController.showRecalibrationPrompt) {
            Button("Yes, recalibrate") {
                cameraController.isCalibrationMode = true
                cameraController.resetCalibration()
            }
            Button("No, continue with existing calibration", role: .cancel) {
                cameraController.showRecalibrationPrompt = false
            }
        }
        .onAppear {
            OrientationController.shared.lockOrientation(.landscapeRight)
            cameraController.startSession()
        }
        .onDisappear {
            OrientationController.shared.lockOrientation(.portrait)
            cameraController.stopSession()
        }
    }
    
    private func getCalibrationPointColor(for index: Int) -> Color {
        let colors: [Color] = [.red, .blue, .green, .orange]
        return colors[index % colors.count]
    }
    
    // Helper function to get appropriate visual indicator for each calibration step
    private func getCalibrationTargetIndicator(for step: Int) -> some View {
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

class UICameraPreview: UIView {
   
}

struct CameraPreview: UIViewRepresentable {
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 如果需要更新UIView，则在此处进行操作
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UICameraPreview()
        CameraController.shared.preView = view
        return view
    }
}
