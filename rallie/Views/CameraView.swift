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
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    CameraPreviewControllerWrapper(controller: cameraController)
                    
                    // Joints overlay
                    JointsView(
                        joints: cameraController.detectedJoints,
                        originalSize: cameraController.originalFrameSize,
                        viewSize: geometry.size
                    )
                    .allowsHitTesting(false) // Allow taps to pass through
                    
                    // Action prediction overlay
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Action: \(cameraController.currentAction)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Confidence: \(Int(cameraController.actionConfidence * 100))%")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding()
                            .allowsHitTesting(false) // Allow taps to pass through
                        }
                    }
                    
                    // Transparent overlay to capture taps
                    Color.clear
                        .frame(width: geometry.size.width, height: geometry.size.height)
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
                        CalibrationPointsView(cameraController: cameraController)
                    } else {
                        OverlayShapeView(
                            isActivated: true, cameraController: cameraController
                        )
                    }
                }
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
                
                // Only show calibration instructions when in calibration mode
                if cameraController.isCalibrationMode {
                    Text("Tap the 5 key points on the court to calibrate")
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.top, 10)
                }

                Spacer()
            }
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
            // Start camera session when view appears
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let screenSize = window.bounds.size
                cameraController.startSession(in: window, screenSize: screenSize)
            }
        }
        .onDisappear {
            // Stop camera session when view disappears
            cameraController.stopSession()
        }
    }
    
    private func getCalibrationPointColor(for index: Int) -> Color {
        let colors: [Color] = [.red, .blue, .green, .orange]
        return colors[index % colors.count]
    }
}
