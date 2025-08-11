# Mavio - Integrated Tennis Training Platform

This project aims to combine two demo apps of the Mavio project into one integrated platform. Together they provide a comprehensive, interactive, and intelligent training experience with the Mavio tennis ball machine for tennis players.

## 🎾 Project Overview

Mavio integrates two key components:

1. **LLM Planning and Analysis** - Pre and post-training session analysis using large language models to provide personalized insights, training plans, and performance feedback.

2. **Machine Control and Computer Vision** - Real-time interactive training experience with computer vision-based player tracking and automated ball machine control.

## 🔑 Key Features

### LLM Planning and Analysis
- **Pre-training Planning**: AI-generated personalized training plans based on player goals and skill level
- **Post-training Analysis**: Detailed performance analysis and feedback after training sessions
- **Progress Tracking**: Long-term skill development monitoring and adaptive training recommendations

### Machine Control and Computer Vision
- **Real-time Player Tracking**: Detects player position on court using computer vision
- **Interactive Ball Placement**: Automatically adjusts shot placement based on player movement
- **Action Classification**: Recognizes player actions and stances for targeted training
- **Bluetooth Machine Control**: Precise control of the Mavio tennis ball machine parameters

## 🛠️ Technical Architecture

The integrated platform combines:

- **Swift/SwiftUI**: Core iOS application framework
- **Vision Framework**: Apple's computer vision for player detection and pose estimation
- **CoreBluetooth**: Communication with the Mavio tennis ball machine
- **OpenCV**: Court homography and coordinate mapping
- **CoreML**: On-device action classification and player analysis

## 📱 User Experience

The app provides a seamless experience through:

1. **Training Planning**: Create and customize training sessions with AI assistance
2. **Interactive Training**: Real-time machine control based on player position and actions
3. **Performance Review**: Post-session analysis with actionable insights and recommendations

## 🧩 Integration Points

The two previously separate applications are now integrated through:

- **Shared Data Model**: Common player profile and session data
- **Unified Interface**: Seamless transition between planning and training modes
- **Continuous Learning**: Training data feeds back into planning system for improved recommendations

## 🚀 Getting Started

See the individual component READMEs for detailed setup instructions:
- [Machine Control and CV Analysis](./rallie/README.md)
- [LLM Planning and Analysis](./llm-planning/README.md)

## 📋 Requirements

- iOS 15.0+
- Xcode 13.0+
- Mavio Tennis Ball Machine with Bluetooth capability
- iPhone with A12 Bionic chip or newer (for optimal CV performance)

## 🔄 Current Development Status

This project is under active development with a focus on:
- Improving joint detection and filtering for better player tracking
- Enhancing Bluetooth communication reliability with the ball machine
- Integrating the LLM planning and CV analysis components
