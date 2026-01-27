import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var selectedTab: Int = 0
    @State private var showingSettings = false
    
    init() {
        // Centralize tab appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.surface)
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.primary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColors.primary)]
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textSecondary)]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(AppColors.primary)
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppColors.textSecondary)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ImprovedPhoneMainView()
                .tabItem {
                    Label("Ruck", systemImage: "figure.walk")
                }
                .tag(0)
            
            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(1)
            
            CommunityTribeView()
                .tabItem {
                    Label("Tribe", systemImage: "person.3.fill")
                }
                .tag(2)
            
            ActivityContainer(showSettings: $showingSettings)
                .tabItem {
                    Label("You", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .accentColor(AppColors.primary)
        .preferredColorScheme(.dark)
        .background(AppColors.backgroundGradient.ignoresSafeArea())
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(HealthManager.shared)
        .environmentObject(WorkoutManager())
        .environmentObject(WorkoutDataManager.shared)
        .environmentObject(PremiumManager.shared)
}

private struct ActivityContainer: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @Binding var showSettings: Bool
    
    var body: some View {
        NavigationView {
            AnalyticsView(showAllWorkouts: .constant(false))
                .environmentObject(workoutDataManager)
                .environmentObject(premiumManager)
                .navigationTitle("Activity")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
        }
    }
}

