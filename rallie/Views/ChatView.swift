import SwiftUI

/// Message model for chat
struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var openAIService = OpenAIService.shared
    @ObservedObject private var planManager = TrainingPlanManager.shared
    
    @State private var messages: [ChatMessage] = []
    @State private var inputMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showingProfileSheet: Bool = false
    @State private var playerProfile = PlayerProfile(
        name: "",
        skillLevel: "Intermediate",
        playStyle: "All-court",
        focusAreas: ["Forehand", "Backhand"],
        sessionDuration: 30
    )
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // Skill level options
    private let skillLevels = ["Beginner", "Intermediate", "Advanced", "Professional"]
    
    // Play style options
    private let playStyles = ["All-court", "Baseline", "Serve and Volley", "Aggressive Baseliner", "Defensive Baseliner"]
    
    // Focus areas options
    private let focusAreaOptions = ["Forehand", "Backhand", "Serve", "Volley", "Footwork", "Consistency", "Power", "Accuracy"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Chat messages
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                chatBubble(for: message)
                            }
                            
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                                .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            scrollView.scrollTo(messages.last?.id ?? "loading", anchor: .bottom)
                        }
                    }
                    .onChange(of: isLoading) { _ in
                        withAnimation {
                            scrollView.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Input area
                HStack {
                    TextField("Message AI Coach...", text: $inputMessage)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .disabled(isLoading)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                            .padding(10)
                    }
                    .disabled(inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("AI Tennis Coach")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingProfileSheet = true
                    }) {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .onAppear {
                // Add welcome message
                if messages.isEmpty {
                    let welcomeMessage = ChatMessage(
                        id: UUID().uuidString,
                        content: "Hi! I'm your AI tennis coach. I can help create a personalized training plan based on your skill level, play style, and areas you want to focus on. Would you like to set up your player profile first?",
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(welcomeMessage)
                }
                
                // Check if API key is set
                if openAIService.getAPIKey() == nil {
                    alertMessage = "Please set your OpenAI API key in Settings to use the AI Coach feature."
                    showingAlert = true
                }
            }
            .sheet(isPresented: $showingProfileSheet) {
                playerProfileView
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("AI Coach"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Chat bubble view
    private func chatBubble(for message: ChatMessage) -> some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.isFromUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
        .id(message.id)
    }
    
    // Format timestamp
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Send message function
    private func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Check if API key is set
        guard openAIService.getAPIKey() != nil else {
            alertMessage = "Please set your OpenAI API key in Settings to use the AI Coach feature."
            showingAlert = true
            return
        }
        
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            content: inputMessage,
            isFromUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        
        let userInput = inputMessage
        inputMessage = ""
        isLoading = true
        
        // Check if the message contains a request for a training plan
        if userInput.lowercased().contains("plan") || 
           userInput.lowercased().contains("training") || 
           userInput.lowercased().contains("create") {
            
            // Generate a training plan based on the player profile
            generateTrainingPlan()
        } else {
            // Regular chat response
            openAIService.getChatResponse(messages: messages) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    switch result {
                    case .success(let response):
                        let aiMessage = ChatMessage(
                            id: UUID().uuidString,
                            content: response,
                            isFromUser: false,
                            timestamp: Date()
                        )
                        messages.append(aiMessage)
                        
                    case .failure(let error):
                        let errorMessage = ChatMessage(
                            id: UUID().uuidString,
                            content: "Sorry, I encountered an error: \(error.localizedDescription). Please try again.",
                            isFromUser: false,
                            timestamp: Date()
                        )
                        messages.append(errorMessage)
                    }
                }
            }
        }
    }
    
    // Generate training plan
    private func generateTrainingPlan() {
        // Check if player profile is complete
        if playerProfile.name.isEmpty {
            isLoading = false
            let profileMessage = ChatMessage(
                id: UUID().uuidString,
                content: "Before I create a training plan, I need some information about you. Please set up your player profile by tapping the profile icon in the top right corner.",
                isFromUser: false,
                timestamp: Date()
            )
            messages.append(profileMessage)
            return
        }
        
        // Generate a training plan using OpenAI
        openAIService.generateTrainingPlan(for: playerProfile) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let plan):
                    // Save the generated plan
                    planManager.savePlan(plan)
                    
                    // Create a response message with the plan details
                    var planDescription = "I've created a training plan for you: **\(plan.title)**\n\n"
                    planDescription += "\(plan.description)\n\n"
                    planDescription += "Total duration: \(plan.totalDuration) minutes\n\n"
                    planDescription += "The plan includes \(plan.segments.count) segments:\n"
                    
                    for (index, segment) in plan.segments.enumerated() {
                        planDescription += "\(index + 1). **\(segment.name)** (\(segment.duration) min) - \(segment.focus)\n"
                    }
                    
                    planDescription += "\nYou can find this plan in the Training Plans tab. Would you like me to create another plan or modify this one?"
                    
                    let planMessage = ChatMessage(
                        id: UUID().uuidString,
                        content: planDescription,
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(planMessage)
                    
                case .failure(let error):
                    let errorMessage = ChatMessage(
                        id: UUID().uuidString,
                        content: "Sorry, I couldn't generate a training plan: \(error.localizedDescription). Please try again.",
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(errorMessage)
                }
            }
        }
    }
    
    // Player profile view
    private var playerProfileView: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Your Name", text: $playerProfile.name)
                    
                    Picker("Skill Level", selection: $playerProfile.skillLevel) {
                        ForEach(skillLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    
                    Picker("Play Style", selection: $playerProfile.playStyle) {
                        ForEach(playStyles, id: \.self) { style in
                            Text(style).tag(style)
                        }
                    }
                }
                
                Section(header: Text("Focus Areas")) {
                    ForEach(focusAreaOptions, id: \.self) { area in
                        Toggle(area, isOn: Binding(
                            get: { playerProfile.focusAreas.contains(area) },
                            set: { isSelected in
                                if isSelected {
                                    playerProfile.focusAreas.append(area)
                                } else {
                                    playerProfile.focusAreas.removeAll { $0 == area }
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("Session Duration")) {
                    Picker("Duration (minutes)", selection: $playerProfile.sessionDuration) {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { duration in
                            Text("\(duration) minutes").tag(duration)
                        }
                    }
                }
            }
            .navigationTitle("Player Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        showingProfileSheet = false
                    }
                }
            }
        }
    }
}

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
#endif
