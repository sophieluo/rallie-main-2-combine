# Mavio LLM Planning Feature

## Overview

The LLM Planning feature integrates AI-powered training plan generation into the Mavio tennis training app. This feature allows users to create personalized tennis training plans based on their skill level, play style, and focus areas. The plans are structured in a consistent format with segments that include machine settings (speed, spin, position) and focus areas for each drill.

## Key Components

### Data Models

- **TrainingPlan**: Represents a complete training plan with multiple segments
- **TrainingSegment**: Individual drills or exercises within a plan
- **MachineSettings**: Configuration for the tennis ball machine (speed, spin, position, quantity)
- **PlayerProfile**: User information for personalized plan generation
- **TrainingSession**: Tracks the execution of a training plan

### Services

- **OpenAIService**: Handles communication with the OpenAI API
  - Securely stores API keys in Keychain
  - Constructs prompts based on player profiles
  - Parses JSON responses into training plans
  - Handles error cases and validation

### Controllers

- **TrainingPlanManager**: Manages training plans and sessions
  - Saves and retrieves plans from local storage
  - Controls training session execution
  - Integrates with BluetoothManager for machine control
  - Tracks segment timing and progression

### Views

- **ChatView**: Interface for AI coach interaction
  - Allows conversation with the AI coach
  - Supports player profile editing
  - Displays generated plans
  
- **TrainingPlansView**: List of saved training plans
  - Shows plan details and segments
  - Supports plan deletion
  
- **TrainingPlanDetailView**: Detailed view of a specific plan
  - Displays all segments and machine settings
  - Provides controls for executing the plan
  
- **SettingsView**: Configuration for the app
  - Manages OpenAI API key
  - Shows app information

## Integration Points

The LLM Planning feature integrates with the existing app through:

1. **BluetoothManager**: Sends commands to the tennis ball machine
2. **MainTabView**: Provides navigation between app sections
3. **HomeView**: Existing main view for machine control

## Testing

Unit tests are provided for:

- **TrainingPlanModels**: Tests data model serialization/deserialization
- **OpenAIService**: Tests API key management, prompt construction, and JSON parsing
- **TrainingPlanManager**: Tests plan storage, session management, and machine control

## Usage

1. **Set up API Key**: Enter your OpenAI API key in the Settings tab
2. **Create a Plan**: Go to the Training tab and tap the + button
3. **Configure Profile**: Enter your name, skill level, and preferences
4. **Generate Plan**: Chat with the AI coach to create a personalized plan
5. **Execute Plan**: Open a plan and tap "Start Training Session"
6. **Control Session**: Use the playback controls to navigate through segments

## Requirements

- iOS 15.0+
- OpenAI API key (GPT-4 or GPT-3.5-Turbo)
- Bluetooth-enabled tennis ball machine compatible with Mavio

## Future Enhancements

- Plan editing capabilities
- History of completed sessions
- Performance analytics
- Sharing plans between users
