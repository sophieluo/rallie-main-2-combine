# Rallie iOS App – Developer Overview

Welcome to the Rallie iOS project. This app powers an AI-driven tennis ball machine that interacts with the player in real time. The system uses the phone's camera, computer vision (via Apple Vision framework), and Bluetooth to dynamically adjust shot placement based on the player's position.

---

## 🔧 Key Features

- **Real-Time Player Detection**: Detects player's feet position on court using `VNDetectHumanRectanglesRequest`.
- **Homography Mapping**: Maps the detected position from the image space to real-world court coordinates.
- **Mini Court Visualization**: Displays player’s projected position and user taps on a mini virtual court.
- **Zone-Based Ball Placement Logic**: Divides the court into 16 zones (4x4) and chooses pre-tuned commands for shot delivery.
- **Command Transmission via Bluetooth**: Sends 18-digit commands to the ball machine.
- **CSV Logging**: Logs player positions to `player_positions.csv` in `Documents/` directory for debugging and training.

---

## 🗂 Folder Structure

```
rallie/
├── AppEntry/
│   └── rallieApp.swift                  # Main app entry point
├── Assets.xcassets/                    # Image and asset catalog
├── Controllers/
│   └── BluetoothManager.swift          # Sends BLE commands to ball machine
│   └── CameraController.swift          # Handles camera input & Vision
│   └── LogicManager.swift              # Processes player positions & generates commands
├── Docs/
│   └── CommandBroadcastingLogic.md     # Developer documentation for command logic
├── Frameworks/
├── Preview Content/
├── Resources/
├── Utils/
│   └── CommandLookup.swift             # Zone-to-command lookup logic
│   └── CourtLayout.swift               # Real-world court dimensions and reference points
│   └── HomographyHelper.swift          # Computes court homography using OpenCV
│   └── LandscapeHostingController.swift # Force landscape mode wrapper
│   └── OpenCVWrapper.{h,mm}            # OpenCV bridging header and implementation
├── Views/
│   └── CameraPreviewControllerWrapper.swift  # UIKit wrapper to embed camera
│   └── CameraPreviewView.swift               # Preview view with controller
│   └── CameraView.swift                      # Main interactive camera screen
│   └── CourtOverlayView.swift                # Green projected court lines
│   └── HomeView.swift                        # App home screen
│   └── LandscapeWrapper.swift                # Rotates content to landscape
│   └── MiniCourtView.swift                   # Mini map showing player/tap
│   └── OverlayShapeView.swift                # Red alignment trapezoid overlay
├── Vision/
│   └── PlayerDetector.swift            # Handles Vision requests for detecting player
├── Info.plist
```

---

## 📍 Key Logic Flow

1. `CameraController` starts the camera and computes homography once using 4 known court keypoints.
2. Player's feet are detected in each frame and projected into court space.
3. `LogicManager` buffers all projected positions and every 3 seconds:
   - Averages the last 1 second of positions.
   - Maps the average to one of 16 zones.
   - Looks up the zone in `CommandLookup` and sends command via Bluetooth.
4. Projected tap (user touch) and projected player position are both drawn on `MiniCourtView`.

---

## 📤 Command Format

Each command sent to the machine is 18 digits:

```
[00000] upper motor speed
[00000] lower motor speed
[0000]  pitch angle
[0000]  yaw angle
```

These are hardcoded for each zone in `CommandLookup.swift`. You can later update these values from real-world testing.

---

## 📄 CSV Logging

All projected player positions are logged to:

```
Documents/player_positions.csv
```

Use this for visualizing player movement or debugging the homography.

---

## 🧠 Notes for New Developers

- Most vision-related logic lives in `CameraController` and `PlayerDetector`.
- If you want to edit homography points, go to `CourtLayout.swift` → `referenceImagePoints`.
- To modify court overlays, adjust logic in `OverlayHelper.swift`.
- BLE UUIDs are optional; BluetoothManager gracefully skips if not configured.
- To test on device, be sure to use **real iPhone** (not simulator) for camera access and BLE.

---
