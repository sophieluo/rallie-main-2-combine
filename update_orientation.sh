#!/bin/bash

# Path to the project file
PROJECT_FILE="/Users/Sophie_Luo/Desktop/rallie-main-2-combine/rallie.xcodeproj/project.pbxproj"

# Backup the original file
cp "$PROJECT_FILE" "${PROJECT_FILE}.bak"

# Replace the iPhone orientation setting
sed -i '' 's/INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationLandscapeRight;/INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;/g' "$PROJECT_FILE"

echo "Project file updated successfully!"
