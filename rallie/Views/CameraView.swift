import SwiftUI
import UniformTypeIdentifiers

@available(iOS 16.0, *)
struct CameraView: View {
    @ObservedObject var cameraController: CameraController
    @Environment(\.dismiss) private var dismiss

    //share csv
    @State private var showShareSheet = false
    @State private var csvURL: URL? = nil
    @State private var showExportAlert = false

    //broadcast player position
    @StateObject var bluetoothManager = BluetoothManager()
    @StateObject var logicManager: LogicManager

    init(cameraController: CameraController) {
        _cameraController = ObservedObject(wrappedValue: cameraController)
        let bluetooth = BluetoothManager()
        _bluetoothManager = StateObject(wrappedValue: bluetooth)
        _logicManager = StateObject(wrappedValue: LogicManager(
            playerPositionPublisher: cameraController.$projectedPlayerPosition,
            bluetoothManager: bluetooth
        ))
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    CameraPreviewControllerWrapper(controller: cameraController)
                    
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
                }
            }

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
                    
                    // Border
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    // Point number for clarity
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .position(point)
            }
            
            // Calibration or overlay UI
            if cameraController.isCalibrationMode {
                CalibrationPointsView(cameraController: cameraController)
            } else {
                OverlayShapeView(
                    isActivated: cameraController.isTappingEnabled,
                    cameraController: cameraController
                )
            }

            VStack {
                Text(cameraController.isCalibrationMode ?
                     "Tap the 5 key points on the court to calibrate" :
                     "Align the court to fit the red outline. Tap anywhere to start tracking.")
                    .foregroundColor(.white)
                    .padding(.top, 40)

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        MiniCourtView(
                            playerPosition: cameraController.projectedPlayerPosition
                        )
                        .frame(width: 140, height: 100)

                        Button {
                            if let fileURL = getCSVURL() {
                                self.csvURL = fileURL
                                self.showShareSheet = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export CSV")
                            }
                            .foregroundColor(.white)
                            .underline()
                        }
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }

                Spacer()

                // Top-left close button
                HStack {
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
                }

                Spacer()
            }
        }
        .ignoresSafeArea(.all)

        // Overlay the bottom button instead of padding
        .overlay(
            Group {
                if cameraController.isCalibrationMode {
                    // No need for duplicate UI here since CalibrationPointsView handles it
                    EmptyView()
                } else if !cameraController.isTappingEnabled {
                    VStack {
                        Spacer()
                        Button(action: {
                            cameraController.isTappingEnabled = true
                        }) {
                            Text("Aligned - Let's go!")
                                .font(.headline)
                                .padding()
                                .background(Color.blue.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                    }
                }
            },
            alignment: .bottom
        )
        // Add alert for recalibration prompt
        .alert(cameraController.recalibrationMessage, isPresented: $cameraController.showRecalibrationPrompt) {
            Button("Calibrate Now") {
                cameraController.isCalibrationMode = true
                cameraController.resetCalibration()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let file = csvURL {
                ShareSheet(activityItems: [file])
            }
        }
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let screenSize = window.bounds.size
                cameraController.startSession(in: window, screenSize: screenSize)
            }
        }
        .onDisappear {
            cameraController.stopSession()
        }
    }

    // Helper function to get different colors for calibration points
    private func getCalibrationPointColor(for index: Int) -> Color {
        let colors: [Color] = [
            .blue,      // Bottom left
            .green,     // Bottom right
            .yellow,    // Top right
            .pink,      // Top left
            .orange,    // Left service
            .red,       // Right service
            .purple,    // Center service
            .cyan       // Net center
        ]
        return colors[index % colors.count]
    }

    func getCSVURL() -> URL? {
        let fileName = "player_positions.csv"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        }
        return nil
    }

    private func checkCSVContents() -> Bool {
        guard let fileURL = getCSVURL(),
              let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }
        return !contents.isEmpty
    }
}

// MARK: - ShareSheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
