import SwiftUI
import Foundation

// MARK: - Main Phone View Coordinator
struct ImprovedPhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    @State private var showingSettings = false
    @State private var showingWorkoutHistory = false
    @State private var showingTrainingPrograms = false
    @State private var showingChallenges = false
    @State private var showingDataExport = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                mainContentView
                
                // Bottom Navigation Bar
                bottomNavigationBar
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingWorkoutHistory) {
            AllWorkoutsView()
        }
        .sheet(isPresented: $showingTrainingPrograms) {
            TrainingProgramsView()
        }
        .sheet(isPresented: $showingChallenges) {
            ChallengesView()
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
                .environmentObject(workoutDataManager)
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main cards
                justRuckCard
                programsCard
                challengesCard
                dataCard
                
                // Preserve existing functionality sections
                if !workoutDataManager.workouts.isEmpty {
                    QuickStatsDashboard()
                        .environmentObject(workoutDataManager)
                }
                
                // Premium Analytics - only show if user has data
                if workoutDataManager.totalWorkouts >= 3 {
                    PremiumAnalyticsSection()
                        .environmentObject(workoutDataManager)
                }
                
                if workoutDataManager.totalWorkouts >= 5 {
                    TrainingInsightsSection()
                        .environmentObject(workoutDataManager)
                        .environmentObject(workoutManager)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
    }
    
    // MARK: - Main Action Cards
    
    private var justRuckCard: some View {
        Button(action: {
            // Start workout logic
            workoutManager.startWorkout()
        }) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Just Ruck")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Start a workout on your Apple Watch")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "applewatch")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                if workoutManager.isActive {
                    ActiveWorkoutStatusCard()
                        .environmentObject(workoutManager)
                } else {
                    QuickSetupCard()
                        .environmentObject(workoutManager)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var programsCard: some View {
        Button(action: {
            showingTrainingPrograms = true
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Training Programs")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    
                    Text("Structured military training plans")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var challengesCard: some View {
        Button(action: {
            showingChallenges = true
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Challenges")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Coming soon - fitness challenges")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var dataCard: some View {
        Button(action: {
            showingDataExport = true
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data & Export")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Export your workout data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Navigation Bar
    
    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            // Profile Button
            Button(action: {
                // Profile functionality - could open user profile or account settings
                showingSettings = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Profile")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Activity Button
            Button(action: {
                showingWorkoutHistory = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Settings Button
            Button(action: {
                showingSettings = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Settings")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -1)
        )
    }
}

// MARK: - Preview
#Preview {
    ImprovedPhoneMainView()
        .environmentObject(WorkoutManager())
        .environmentObject(WorkoutDataManager.shared)
        .environmentObject(PremiumManager.shared)
}
