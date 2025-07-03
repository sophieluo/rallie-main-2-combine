# 🧠 LogicManager + CommandLookup: Player-Aware Smart Serving  
_Last updated: April 2025_

## 📌 Overview

This feature enables **real-time decision-making** for your AI-powered tennis ball machine based on the player’s on-court position. Every 3 seconds, the system evaluates the player's position, determines which court zone they're in, and sends a preconfigured 18-digit command to the ball machine via Bluetooth.

---

## 🎯 Purpose

- **Adaptively serve** balls toward the player's likely hitting side (right-handed by default)
- Mimic how a real coach feeds balls based on the player’s location
- Provide a basic “position-aware” AI demo loop

---

## ⚙️ Key Components

### 1. `LogicManager.swift`

This class:

- Subscribes to `projectedPlayerPosition` from the Vision system
- Buffers recent player positions with timestamps
- Every 3 seconds:
  - Averages the player’s position over the most recent 1 second
  - Identifies which zone the player is in
  - Loads the corresponding 18-digit command
  - Sends it to the Bluetooth manager

**Smoothing logic**:
- Keeps 3 seconds of data
- Only uses the last 1 second for averaging
- Ensures smoother and more reliable placement targeting

---

### 2. `CommandLookup.swift`

This struct:

- Defines a **4×4 grid** of the court (16 zones total)
- Maps each zone ID (0–15) to a hardcoded 18-digit command string
- Falls back to a default command if the player is out of bounds

**Each 18-digit command format**:
```
[upper motor: 5 digits][lower motor: 5 digits][pitch: 4 digits][yaw: 4 digits]
```

---

## 🔄 Command Timing

- Commands are sent **once every 3 seconds**
- Only if at least one recent position is available
- Reduces noise, conserves BLE bandwidth, and mimics realistic hitting cadence

---

## 🧪 Configuration

| What                        | Where                            |
|----------------------------|----------------------------------|
| Grid size (e.g. 5×3)       | `CommandLookup.zoneID()`         |
| Command table              | `CommandLookup.hardcodedCommands`|
| Fallback command           | `CommandLookup.fallbackCommand`  |
| Interval (e.g. 2s, 5s)     | `LogicManager.commandInterval`   |
| Smoothing window           | `LogicManager.attemptToSendSmoothedCommand()` |

---

## 🧩 Example Command Mapping

| Zone ID | Description                    | Command             |
|---------|--------------------------------|---------------------|
| 0       | Far left baseline              | `110001100000...`   |
| 5       | Near center service area       | `120001100001...`   |
| 15      | Near right net area            | `130001200003...`   |

---

## ✅ Future Improvements

- Dynamically learn or calibrate commands per zone
- Add support for left-handed vs right-handed serving
- Tune zone layout to better reflect real-world movement patterns
- Add velocity or pose prediction for next-level AI behavior