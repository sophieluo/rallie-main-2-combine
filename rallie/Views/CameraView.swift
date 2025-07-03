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
                CameraPreviewControllerWrapper(controller: cameraController)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let location = value.location
                                if cameraController.isTappingEnabled {
                                    cameraController.handleUserTap(location)
                                }
                            }
                    )
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
                     "Drag the colored points to the 4 corners of the court" :
                     "Align the court to fit the red outline")
                    .foregroundColor(.white)
                    .padding(.top, 40)

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        MiniCourtView(
                            tappedPoint: cameraController.lastProjectedTap,
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

        // ✅ Overlay the bottom button instead of padding
        .overlay(
            Group {
                if cameraController.isCalibrationMode {
                    VStack {
                        Spacer()
                        Button(action: {
                            cameraController.computeHomographyFromCalibrationPoints()
                            cameraController.isCalibrationMode = false
                        }) {
                            Text("Calibration Complete")
                                .font(.headline)
                                .padding()
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                    }
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
