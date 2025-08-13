import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    @ObservedObject var cameraController: CameraController
    @ObservedObject var bluetoothManager = BluetoothManager.shared
    @ObservedObject var logicManager = LogicManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var deviceOrientation = UIDevice.current.orientation
    
    init(cameraController: CameraController) {
        _cameraController = ObservedObject(wrappedValue: cameraController)
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewControllerWrapper(controller: cameraController)
            
            // Joints and court lines
            GeometryReader { geometry in
                ZStack {
                    // Joints overlay
                    JointsView(
                        joints: cameraController.detectedJoints,
                        originalSize: cameraController.originalFrameSize,
                        viewSize: geometry.size
                    )
                    
                    // Court lines overlay
                    Path { path in
                        for line in cameraController.projectedCourtLines {
                            path.move(to: line.start)
                            path.addLine(to: line.end)
                        }
                    }
                    .stroke(Color.green, lineWidth: 2)
                    
                    // Calibration points
                    ForEach(0..<cameraController.userTappedPoints.count, id: \.self) { index in
                        let point = cameraController.userTappedPoints[index]
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 30, height: 30)
                            
                            Circle()
                                .fill(getCalibrationPointColor(for: index))
                                .frame(width: 20, height: 20)
                            
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .position(x: point.x, y: point.y)
                    }
                    
                    // Calibration or overlay UI
                    if cameraController.isCalibrationMode {
                        CalibrationPointsView(cameraController: cameraController)
                    } else {
                        OverlayShapeView(
                            isActivated: true, cameraController: cameraController
                        )
                    }
                    
                    // Transparent overlay to capture taps
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    if cameraController.isCalibrationMode {
                                        cameraController.handleCalibrationTap(at: value.location)
                                    }
                                }
                        )
                }
            }
            
            // UI Controls - Hardcoded positions
            VStack {
                HStack {
                    Spacer()
                    
                    // Close button in upper right in portrait
                    Button(action: {
                        cameraController.stopSession()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .padding(20)
                    }
                    .rotationEffect(deviceOrientation.isPortrait ? .degrees(90) : .degrees(0))
                }
                
                Spacer()
                
                HStack {
                    // Action classification in lower left in portrait
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
                    .padding(20)
                    .rotationEffect(deviceOrientation.isPortrait ? .degrees(90) : .degrees(0))
                    
                    Spacer()
                    
                    // Mini court in bottom right
                    if !cameraController.isCalibrationMode {
                        MiniCourtView(playerPosition: cameraController.projectedPlayerPosition)
                            .frame(width: 140, height: 100)
                    }
                }
                
                // Calibration instructions
                if cameraController.isCalibrationMode {
                    Text("Tap the 5 key points on the court to calibrate")
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                        .rotationEffect(deviceOrientation.isPortrait ? .degrees(90) : .degrees(0))
                }
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
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            deviceOrientation = UIDevice.current.orientation
        }
    }
    
    private func getCalibrationPointColor(for index: Int) -> Color {
        let colors: [Color] = [.red, .blue, .green, .orange]
        return colors[index % colors.count]
    }
}
