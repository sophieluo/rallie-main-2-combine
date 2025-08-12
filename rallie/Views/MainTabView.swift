import SwiftUI

/// Main tab view for the app navigation
struct MainTabView: View {
    // MARK: - Properties
    
    @State private var selectedTab = 0
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Control view (existing main view)
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Training Plans view
            TrainingPlansView()
                .tabItem {
                    Label("Training", systemImage: "figure.tennis")
                }
                .tag(1)
            
            // AI Coach view
            ChatView()
                .tabItem {
                    Label("AI Coach", systemImage: "bubble.left.fill")
                }
                .tag(2)
            
            // Settings view
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
#endif
