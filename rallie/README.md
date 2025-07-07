# Rallie iOS App – Developer Overview

Welcome to the Rallie iOS project. This app powers an AI-driven tennis ball machine that interacts with the player in real time. The system uses the phone's camera, computer vision (via Apple Vision framework), and Bluetooth to dynamically adjust shot placement based on the player's position.

---

## 🔧 Key Features

- **Real-Time Player Detection**: Detects player's feet position on court using `VNDetectHumanRectanglesRequest`.
- **Homography Mapping**: Maps the detected position from the image space to real-world court coordinates.
- **Mini Court Visualization**: Displays player's projected position and user taps on a mini virtual court.
- **Interactive & Manual Modes**: Supports both manual target selection and real-time interactive mode based on player position.
- **Custom Zone-Based Ball Placement**: Divides the court into 16 non-uniform zones with custom boundaries for precise targeting.
- **Configurable Ball Parameters**: Adjustable ball speed (20-80mph) and spin types (flat, topspin, extreme topspin).
- **Adjustable Launch Intervals**: User can set ball launch frequency from 2 to 9 seconds.
- **Command Transmission via Bluetooth**: Sends 10-byte binary commands to the ball machine using protocol v0.3.

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
3. `LogicManager` operates in one of two modes:
   - **Manual Mode**: User taps to select target points, commands sent immediately.
   - **Interactive Mode**: Real-time tracking of player position with the following logic:
     - Buffers all projected positions with timestamps.
     - Sends commands at user-defined intervals (2-9 seconds).
     - Averages recent positions (adaptive window based on launch interval).
     - Maps the average to one of 16 custom zones.
     - Looks up the zone, speed, and spin in `CommandLookup` and sends command via Bluetooth.
4. Projected tap (user touch) and projected player position are both drawn on `MiniCourtView`.

---

## 📤 Bluetooth Protocol v0.3

Each command sent to the machine is a 10-byte binary message:

| Byte | Parameter      | Range   | Description                           |
|------|---------------|---------|---------------------------------------|
| 0    | Header 1      | 0x5A    | Fixed header byte                     |
| 1    | Header 2      | 0xA5    | Fixed header byte                     |
| 2    | Source        | 0x83    | Source identifier                     |
| 3    | Upper Wheel   | 0-100   | Upper wheel motor speed (percentage)  |
| 4    | Lower Wheel   | 0-100   | Lower wheel motor speed (percentage)  |
| 5    | Pitch Angle   | 0-90    | Ball pitch angle (degrees)            |
| 6    | Yaw Angle     | 0-90    | Ball yaw angle (degrees)              |
| 7    | Feed Speed    | 0-100   | Ball feed motor speed (percentage)    |
| 8    | Control       | 0/1     | 0=Stop, 1=Start ball machine          |
| 9    | CRC           | 0-255   | XOR checksum of bytes 0-8             |

The machine responds with a 5-byte message:

| Byte | Parameter      | Range   | Description                           |
|------|---------------|---------|---------------------------------------|
| 0    | Header 1      | 0x5A    | Fixed header byte                     |
| 1    | Header 2      | 0xA5    | Fixed header byte                     |
| 2    | Source        | 0x82    | Source identifier                     |
| 3    | Response      | 0-2     | 0=Rejected, 1=Accepted, 2=Completed   |
| 4    | CRC           | 0-255   | XOR checksum of bytes 0-3             |

---

## 🎯 Court Zone Layout

The court is divided into 16 custom zones:
- 4 columns of equal width (25% of court width each)
- 4 rows of varying heights (0-20%, 20-40%, 40-70%, and 70-100% of court height)

Each zone has pre-calibrated commands for:
- 7 different ball speeds (20, 30, 40, 50, 60, 70, 80 mph)
- 3 different spin types (flat, topspin, extreme topspin)

This creates a total of 336 unique ball trajectory combinations (16 zones × 7 speeds × 3 spins).

---

## 🧠 Notes for New Developers

- Most vision-related logic lives in `CameraController` and `PlayerDetector`.
- If you want to edit homography points, go to `CourtLayout.swift` → `referenceImagePoints`.
- To modify court overlays, adjust logic in `OverlayHelper.swift`.
- BLE UUIDs are configured in Info.plist; the app now requires both command and response characteristic UUIDs.
- The `CommandLookup` module uses a 3D lookup table for all 336 combinations of zone, speed, and spin.
- `LogicManager` supports toggling between manual and interactive modes, as well as controlling ball machine state.
- Launch intervals can be adjusted from 2-9 seconds using the `setLaunchInterval()` method in `LogicManager`.
- To test on device, be sure to use **real iPhone** (not simulator) for camera access and BLE.

---
