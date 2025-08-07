//
//  ActionClassifierView.swift
//  rallie
//
//  Created on 2025-08-06.
//

import SwiftUI
import Combine

struct ActionClassifierView: View {
    @ObservedObject var cameraController = CameraController.shared
    @State private var showAllPredictions = false
    @State private var predictions: [(startFrame: Int, endFrame: Int, label: String, confidence: Float)] = []
    
    var body: some View {
        VStack {
            // Current Action Display
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Tennis Action:")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(cameraController.currentAction)
                        .font(.headline)
                        .foregroundColor(actionColor(cameraController.actionConfidence))
                }
                
                HStack {
                    Text("Confidence:")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f", cameraController.actionConfidence))
                        .font(.subheadline)
                }
                
                // Confidence Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .opacity(0.3)
                            .foregroundColor(Color.gray)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(cameraController.actionConfidence) * geometry.size.width, geometry.size.width), height: 8)
                            .foregroundColor(actionColor(cameraController.actionConfidence))
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
                .padding(.vertical, 5)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            // View All Results Button
            Button(action: {
                predictions = cameraController.predictions
                showAllPredictions = true
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("View All Actions")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.top, 5)
            .sheet(isPresented: $showAllPredictions) {
                ActionPredictionsView(predictions: predictions)
            }
        }
    }
    
    private func actionColor(_ confidence: Float) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

struct ActionPredictionsView: View {
    let predictions: [(startFrame: Int, endFrame: Int, label: String, confidence: Float)]
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    var filteredPredictions: [(startFrame: Int, endFrame: Int, label: String, confidence: Float)] {
        if searchText.isEmpty {
            return predictions
        } else {
            return predictions.filter { prediction in
                prediction.label.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                TextField("Search by action", text: $searchText)
                    .padding(7)
                    .padding(.horizontal, 25)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal, 10)
                    .overlay(
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 15)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    self.searchText = ""
                                }) {
                                    Image(systemName: "multiply.circle.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 15)
                                }
                            }
                        }
                    )
                    .padding(.top)
                
                // Results list
                List {
                    ForEach(filteredPredictions, id: \.startFrame) { prediction in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prediction.label)
                                .font(.headline)
                            
                            HStack {
                                Text("Frames: \(prediction.startFrame)-\(prediction.endFrame)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Confidence: \(String(format: "%.2f", prediction.confidence))")
                                    .font(.subheadline)
                                    .foregroundColor(confidenceColor(prediction.confidence))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Summary
                VStack(alignment: .leading, spacing: 4) {
                    Text("Summary")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Text("Total detections: \(predictions.count)")
                        Spacer()
                        Text("Unique actions: \(Set(predictions.map { $0.label }).count)")
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                    
                    // Action distribution
                    let actionCounts = actionDistribution()
                    if !actionCounts.isEmpty {
                        Text("Action Distribution:")
                            .font(.subheadline)
                            .padding(.top, 4)
                            .padding(.horizontal)
                        
                        ForEach(actionCounts.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { action, count in
                            HStack {
                                Text(action)
                                Spacer()
                                Text("\(count) (\(Int((Float(count) / Float(predictions.count)) * 100))%)")
                            }
                            .font(.caption)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
            }
            .navigationTitle("Tennis Actions")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func actionDistribution() -> [String: Int] {
        var counts: [String: Int] = [:]
        
        for prediction in predictions {
            counts[prediction.label, default: 0] += 1
        }
        
        return counts
    }
}

struct ActionClassifierView_Previews: PreviewProvider {
    static var previews: some View {
        ActionClassifierView()
    }
}
