import SwiftUI

/// View for displaying and managing training plans
struct TrainingPlansView: View {
    // MARK: - Properties
    
    @ObservedObject private var planManager = TrainingPlanManager.shared
    @State private var showingChatView = false
    @State private var selectedPlan: TrainingPlan?
    @State private var showingPlanDetail = false
    @State private var showingDeleteConfirmation = false
    @State private var planToDelete: TrainingPlan?
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                if planManager.savedPlans.isEmpty {
                    emptyStateView
                } else {
                    plansList
                }
            }
            .navigationTitle("Training Plans")
            .navigationBarItems(trailing: Button(action: {
                showingChatView = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
            })
            .sheet(isPresented: $showingChatView) {
                ChatView()
            }
            .sheet(isPresented: $showingPlanDetail) {
                if let plan = selectedPlan {
                    TrainingPlanDetailView(plan: plan)
                }
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Delete Plan"),
                    message: Text("Are you sure you want to delete this training plan? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let plan = planToDelete {
                            planManager.deletePlan(withId: plan.id)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // MARK: - Components
    
    /// Empty state view when no plans are available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sportscourt")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Training Plans Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first personalized training plan with the AI Coach.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingChatView = true
            }) {
                Text("Create Plan")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    /// List of saved training plans
    private var plansList: some View {
        List {
            ForEach(planManager.savedPlans.sorted(by: { $0.createdAt > $1.createdAt })) { plan in
                planRow(for: plan)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPlan = plan
                        showingPlanDetail = true
                    }
            }
            .onDelete(perform: confirmDelete)
        }
    }
    
    /// Row for a training plan in the list
    /// - Parameter plan: The plan to display
    /// - Returns: A view representing the plan row
    private func planRow(for plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.title)
                .font(.headline)
            
            HStack {
                Label("\(plan.totalDuration) min", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(plan.segments.count) segments", systemImage: "list.bullet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Show creation date
            Text(formatDate(plan.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    /// Confirm deletion of a plan
    /// - Parameter indexSet: The indices of the plans to delete
    private func confirmDelete(at indexSet: IndexSet) {
        if let index = indexSet.first,
           index < planManager.savedPlans.count {
            planToDelete = planManager.savedPlans.sorted(by: { $0.createdAt > $1.createdAt })[index]
            showingDeleteConfirmation = true
        }
    }
    
    /// Format a date for display
    /// - Parameter date: The date to format
    /// - Returns: A formatted string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// View for displaying and executing a training plan
struct TrainingPlanDetailView: View {
    // MARK: - Properties
    
    let plan: TrainingPlan
    
    @ObservedObject private var planManager = TrainingPlanManager.shared
    @State private var showingSessionControls = false
    @State private var selectedSegmentIndex = 0
    
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Plan details
                VStack(alignment: .leading, spacing: 16) {
                    Text(plan.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label("\(plan.totalDuration) minutes", systemImage: "clock")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Label("\(plan.segments.count) segments", systemImage: "list.bullet")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    
                    Divider()
                }
                .padding()
                
                // Segments list
                List {
                    ForEach(plan.segments.indices, id: \.self) { index in
                        segmentRow(for: plan.segments[index], index: index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSegmentIndex = index
                            }
                            .background(
                                Group {
                                    if planManager.isExecutingPlan && planManager.currentSegmentIndex == index {
                                        Color.blue.opacity(0.1)
                                    } else if selectedSegmentIndex == index {
                                        Color.gray.opacity(0.1)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                    }
                }
                
                // Session controls
                if showingSessionControls {
                    sessionControlsView
                } else {
                    Button(action: {
                        showingSessionControls = true
                    }) {
                        Text("Start Training Session")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding()
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .navigationBarTitle("", displayMode: .inline)
        }
    }
    
    // MARK: - Components
    
    /// Row for a training segment in the list
    /// - Parameters:
    ///   - segment: The segment to display
    ///   - index: The index of the segment
    /// - Returns: A view representing the segment row
    private func segmentRow(for segment: TrainingSegment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index + 1). \(segment.name)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(segment.duration) min")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Machine settings
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed: \(segment.machineSettings.speed) mph")
                    Text("Spin: \(segment.machineSettings.spinType.description)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Balls: \(segment.machineSettings.quantity)")
                    Text("Position: \(Int(segment.machineSettings.position.x / 10))%, \(Int(segment.machineSettings.position.y / 10))%")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Focus area
            Text(segment.focus)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
    
    /// Session controls view
    private var sessionControlsView: some View {
        VStack(spacing: 16) {
            // Progress bar
            if planManager.isExecutingPlan {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current segment: \(plan.segments[planManager.currentSegmentIndex].name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 8)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: geometry.size.width * progressPercentage, height: 8)
                                .foregroundColor(.blue)
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 8)
                    
                    Text(timeRemainingText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Control buttons
            HStack(spacing: 20) {
                if planManager.isExecutingPlan {
                    // Previous segment button
                    Button(action: {
                        planManager.previousSegment()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(22)
                    }
                    .disabled(planManager.currentSegmentIndex == 0)
                    .opacity(planManager.currentSegmentIndex == 0 ? 0.5 : 1)
                    
                    // Pause/Resume button
                    Button(action: {
                        if let session = planManager.currentSession, session.status == .inProgress {
                            planManager.pauseCurrentSession()
                        } else {
                            planManager.resumeCurrentSession()
                        }
                    }) {
                        Image(systemName: planManager.currentSession?.status == .inProgress ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .cornerRadius(30)
                    }
                    
                    // Next segment button
                    Button(action: {
                        planManager.nextSegment()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(22)
                    }
                    .disabled(planManager.currentSegmentIndex == plan.segments.count - 1)
                    .opacity(planManager.currentSegmentIndex == plan.segments.count - 1 ? 0.5 : 1)
                } else {
                    // Start session button
                    Button(action: {
                        _ = planManager.startSession(forPlanId: plan.id)
                    }) {
                        Text("Start")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                
                if planManager.isExecutingPlan {
                    // Stop button
                    Button(action: {
                        planManager.stopCurrentSession()
                        showingSessionControls = false
                    }) {
                        Text("Stop")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                } else {
                    // Cancel button
                    Button(action: {
                        showingSessionControls = false
                    }) {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.vertical)
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
    }
    
    // MARK: - Helper Properties
    
    /// Calculate progress percentage for the current segment
    private var progressPercentage: CGFloat {
        guard planManager.isExecutingPlan,
              let segment = planManager.currentSession.map({ plan.segments[$0.currentSegmentIndex] }) else {
            return 0
        }
        
        let totalSeconds = segment.duration * 60
        let remainingSeconds = planManager.segmentTimeRemaining
        let elapsedSeconds = totalSeconds - remainingSeconds
        
        return CGFloat(elapsedSeconds) / CGFloat(totalSeconds)
    }
    
    /// Format the time remaining for display
    private var timeRemainingText: String {
        let minutes = planManager.segmentTimeRemaining / 60
        let seconds = planManager.segmentTimeRemaining % 60
        return String(format: "%d:%02d remaining", minutes, seconds)
    }
}
