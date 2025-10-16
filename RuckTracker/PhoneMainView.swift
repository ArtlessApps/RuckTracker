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
    @State private var activeSheet: ActiveSheet? = nil
    @State private var isPresentingWorkoutFlow = false
    @State private var showingWeightSelector = false
    @State private var selectedWorkoutWeight: Double = 0
    
    enum ActiveSheet: Identifiable {
        case profile
        case settings
        case analytics
        case workoutHistory
        case trainingPrograms
        case challenges
        case dataExport
        
        var id: Int {
            switch self {
            case .profile: return 0
            case .settings: return 1
            case .analytics: return 2
            case .workoutHistory: return 3
            case .trainingPrograms: return 4
            case .challenges: return 5
            case .dataExport: return 6
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                mainContentView
                
                // Bottom Navigation Bar
                bottomNavigationBar
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .profile:
                ProfileView()
            case .settings:
                SettingsView()
            case .analytics:
                AnalyticsView(showAllWorkouts: $showingWorkoutHistory)
                    .environmentObject(workoutDataManager)
                    .environmentObject(premiumManager)
            case .workoutHistory:
                AllWorkoutsView()
            case .trainingPrograms:
                TrainingProgramsView(isPresentingWorkoutFlow: $isPresentingWorkoutFlow)
            case .challenges:
                ChallengesView(isPresentingWorkoutFlow: $isPresentingWorkoutFlow)
            case .dataExport:
                DataExportView()
                    .environmentObject(workoutDataManager)
            }
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
        .sheet(isPresented: $workoutManager.showingPostWorkoutSummary) {
            PhonePostWorkoutSummaryView(
                finalElapsedTime: workoutManager.finalElapsedTime,
                finalDistance: workoutManager.finalDistance,
                finalCalories: workoutManager.finalCalories,
                finalRuckWeight: workoutManager.finalRuckWeight
            )
            .environmentObject(workoutManager)
        }
        .sheet(isPresented: $showingWeightSelector) {
            WorkoutWeightSelector(
                selectedWeight: $selectedWorkoutWeight,
                isPresented: $showingWeightSelector,
                recommendedWeight: nil,
                context: "Free Ruck",
                onStart: {
                    workoutManager.startWorkout(weight: selectedWorkoutWeight)
                }
            )
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
                                Text("MARCH")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Ruck Tracker with Guided Workouts")
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
                        selectedWorkoutWeight = UserSettings.shared.defaultRuckWeight
                        showingWeightSelector = true
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
                            Color("PrimaryMain").opacity(0.2)
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
                                    Color("PrimaryMain"),
                                    Color("PrimaryMedium"),
                                    Color("BackgroundDark")
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
                activeSheet = .trainingPrograms
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
                        .foregroundColor(Color("TextSecondary"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(Color("PrimaryMain"))
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
                activeSheet = .challenges
            } else {
                premiumManager.showPaywall(context: .featureUpsell)
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weekly Challenges")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    Text("7-Day Focused Challenges")
                        .font(.subheadline)
                        .foregroundColor(Color("TextSecondary"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(Color("PrimaryMain"))
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
                activeSheet = .dataExport
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
                        .foregroundColor(Color("TextSecondary"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(Color("PrimaryMain"))
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
                activeSheet = .profile
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
                activeSheet = .analytics
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
                activeSheet = .settings
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
    @State private var selectedWorkoutWeight: Double = 20.0
    
    var body: some View {
        Button(action: {
            selectedWorkoutWeight = workoutManager.ruckWeight
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
            WorkoutWeightSelector(
                selectedWeight: $selectedWorkoutWeight,
                isPresented: $showingWeightPicker,
                recommendedWeight: nil,
                context: "Adjust Weight",
                onStart: {
                    workoutManager.ruckWeight = selectedWorkoutWeight
                    UserSettings.shared.defaultRuckWeight = selectedWorkoutWeight
                }
            )
        }
    }
}

// MARK: - Preview
#Preview {
    if #available(iOS 17.0, *) {
        ImprovedPhoneMainView()
            .environmentObject(WorkoutManager())
            .environmentObject(WorkoutDataManager.shared)
            .environmentObject(PremiumManager.shared)
    } else {
        Text("Requires iOS 17.0+")
    }
}
