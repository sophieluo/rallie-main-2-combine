//
//  HomeView.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI

struct HomeView: View {
    @State private var showSettings = false
    @ObservedObject var cameraController = CameraController.shared
    @ObservedObject var bluetoothManager = BluetoothManager.shared
    @ObservedObject var logicManager = LogicManager.shared

    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "tennisball.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.bottom, 20)
            
            Text("Welcome to Rallie")
                .font(.largeTitle)
                .padding(.bottom, 10)
                
            Text("AI-Powered Tennis Ball Machine")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)

            Button(action: {
                print("🎾 Settings button tapped")
                showSettings = true
            }) {
                Text("Configure & Start")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 200)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Connection status indicator
            HStack {
                Circle()
                    .fill(bluetoothManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(bluetoothManager.isConnected ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
