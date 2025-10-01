import SwiftUI
import Foundation

// MARK: - Main Phone View Coordinator
struct ImprovedPhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    @State private var showingProfile = false
    @State private var showingSettings = false
    @State private var showingAnalytics = false
    @State private var showingWorkoutHistory = false
    @State private var showingTrainingPrograms = false
    @State private var showingChallenges = false
    @State private var showingDataExport = false
    @State private var showingLeaderboards = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                mainContentView
                
                // Bottom Navigation Bar
                bottomNavigationBar
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView(showAllWorkouts: $showingWorkoutHistory)
                .environmentObject(workoutDataManager)
                .environmentObject(premiumManager)
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
        .sheet(isPresented: $showingLeaderboards) {
            LeaderboardsView()
                .environmentObject(premiumManager)
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
                leaderboardsCard
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
        VStack(spacing: 0) {
            if workoutManager.isActive {
                // Active workout status
                ActiveWorkoutStatusCard()
                    .environmentObject(workoutManager)
            } else {
                // Start Rucking Card
                VStack(spacing: 20) {
                    // Header with unique value proposition
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("RuckTracker")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Military-grade tracking with accurate load calculations")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()

                        }
                        
                        // Key differentiators
                        HStack(spacing: 16) {
                            ClickableWeightPill(weight: workoutManager.ruckWeight)
                                .environmentObject(workoutManager)
                            FeaturePill(icon: "flame.fill", text: "Smart Calories")
                            FeaturePill(icon: "target", text: "Pace Zone")
                        }
                    }
                    
                    // Main start button
                    Button(action: {
                        workoutManager.startWorkout()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.title2)
                            Text("Start Rucking Now")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Color.green.opacity(0.2)
                                .background(.ultraThinMaterial)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Device integration note
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.white.opacity(0.7))
                        Text("Works great on phone")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Image(systemName: "plus")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                        
                        Image(systemName: "applewatch")
                            .foregroundColor(.white.opacity(0.7))
                        Text("enhanced with watch")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.173, green: 0.325, blue: 0.392), // #2C5364
                                    Color(red: 0.125, green: 0.227, blue: 0.263), // #203A43
                                    Color(red: 0.059, green: 0.125, blue: 0.153)  // #0F2027
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
    }
    
    private var programsCard: some View {
        Button(action: {
            if premiumManager.isPremiumUser {
                showingTrainingPrograms = true
            } else {
                premiumManager.showPaywall(context: .programAccess)
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Training Programs")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    
                    Text("Multi-Week Structured Training Plans")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
            if premiumManager.isPremiumUser {
                showingChallenges = true
            } else {
                premiumManager.showPaywall(context: .featureUpsell)
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stack Challenges")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    Text("1 Week Fitness Challenges")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
    
    private var leaderboardsCard: some View {
        Button(action: {
            if premiumManager.isPremiumUser {
                showingLeaderboards = true
            } else {
                premiumManager.showPaywall(context: .featureUpsell)
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Leaderboards")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    Text("Compete with others and track your progress")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
            if premiumManager.isPremiumUser {
                showingDataExport = true
            } else {
                premiumManager.showPaywall(context: .featureUpsell)
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Export Data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    Text("Export your workout data")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
                showingProfile = true
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
                showingAnalytics = true
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

// MARK: - Supporting Views

struct FeaturePill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Color.white.opacity(0.2)
                .cornerRadius(8)
        )
    }
}

struct ClickableWeightPill: View {
    let weight: Double
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showingWeightPicker = false
    
    var body: some View {
        Button(action: {
            showingWeightPicker = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "scalemass")
                    .font(.caption)
                Text("\(Int(weight)) lbs")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color.white.opacity(0.3)
                    .cornerRadius(8)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingWeightPicker) {
            WeightPickerSheet()
                .environmentObject(workoutManager)
        }
    }
}

struct WeightPickerSheet: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    @State private var tempWeight: Double
    
    init() {
        _tempWeight = State(initialValue: 5.0)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Current weight display
                VStack(spacing: 8) {
                    Text("Ruck Weight")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(tempWeight)) lbs")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                // Weight picker
                VStack(spacing: 16) {
                    // Slider
                    VStack(spacing: 8) {
                        Slider(value: $tempWeight, in: 5...100, step: 5)
                            .accentColor(.blue)
                        
                        HStack {
                            Text("5 lbs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("100 lbs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Quick weight buttons
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach([5, 10, 15, 20, 25, 30, 35, 40], id: \.self) { weight in
                            Button(action: {
                                tempWeight = Double(weight)
                            }) {
                                Text("\(weight)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(tempWeight == Double(weight) ? .white : .blue)
                                    .frame(width: 60, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(tempWeight == Double(weight) ? Color.blue : Color.blue.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Info about weight tracking
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Why Weight Matters")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("RuckTracker uses military research to calculate accurate calories based on your pack weight. This makes your fitness data more precise than standard walking apps.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Ruck Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        workoutManager.ruckWeight = tempWeight
                        // Also save to UserSettings for persistence
                        UserSettings.shared.defaultRuckWeight = tempWeight
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            tempWeight = workoutManager.ruckWeight
        }
    }
}

// MARK: - Preview
#Preview {
    ImprovedPhoneMainView()
        .environmentObject(WorkoutManager())
        .environmentObject(WorkoutDataManager.shared)
        .environmentObject(PremiumManager.shared)
}
