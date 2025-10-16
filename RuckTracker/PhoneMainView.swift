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
    @State private var activeTab: ActiveTab = .home
    
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
    
    enum ActiveTab {
        case home
        case profile
        case analytics
        case settings
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
                // dataCard  // Moved to Activity view
                
                // Preserve existing functionality sections
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)  // Accounts for status bar + breathing room
            .padding(.bottom, 20)
        }
        .background(
            ZStack {
                Color("OffWhite")
                
                // Subtle noise texture
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color("AccentCream").opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
    }
    
    // MARK: - Main Action Cards
    
    private var justRuckCard: some View {
        VStack(spacing: 0) {
            if workoutManager.isActive {
                ActiveWorkoutStatusCard()
                    .environmentObject(workoutManager)
            } else {
                ZStack {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("MARCH")
                                        .font(.system(size: 46, weight: .heavy, design: .default))
                                        .foregroundColor(.white)
                                        .tracking(2)
                                    
                                    Text("Your Ruck Training Partner")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.90))
                                }
                                
                                Spacer()
                            }
                        }
                    
                        // BOLD TERRACOTTA BUTTON
                        Button(action: {
                            selectedWorkoutWeight = UserSettings.shared.defaultRuckWeight
                            showingWeightSelector = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.title2)
                                Text("Start Rucking Now")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color("PrimaryMain"))  // Terracotta
                            )
                        }
                        .buttonStyle(HeroButtonStyle())
                    }
                    .padding(28)
                    
                    // Watch connectivity badge positioned at top right
                    VStack {
                        HStack {
                            Spacer()
                            WatchConnectivityBadge()
                                .environmentObject(watchConnectivityManager)
                        }
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 20)
                }
                .background(
                    ZStack {
                        // Base dark color (solid, no gradient needed)
                        Color("BackgroundDark")
                        
                        // Warm terracotta glow - REFINED
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color("PrimaryMain").opacity(0.18),  // Slightly more visible at center
                                        Color("PrimaryMain").opacity(0.08),  // Fades to almost nothing
                                        Color.clear
                                    ]),
                                    center: .topTrailing,
                                    startRadius: 20,
                                    endRadius: 180
                                )
                            )
                            .frame(width: 300, height: 300)
                            .offset(x: 120, y: -80)  // Adjusted position
                    }
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)  // Slightly stronger shadow
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
            HStack(spacing: 12) {
                // Icon with sage background
                ZStack {
                    Circle()
                        .fill(Color("AccentGreen").opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 20))
                        .foregroundColor(Color("AccentGreen"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Training Programs")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .foregroundColor(Color("BackgroundDark"))  // Charcoal, not black
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    
                    Text("Multi-Week Structured Plans")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))  // Not .secondary
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(Color("WarmGray"))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)  // Pure white, not off-white
                    .shadow(color: Color("WarmGray").opacity(0.15), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color("WarmGray").opacity(0.1), lineWidth: 1)
                    )
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
            HStack(spacing: 12) {
                // Icon with dusty teal background
                ZStack {
                    Circle()
                        .fill(Color("AccentTeal").opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color("AccentTeal"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Weekly Challenges")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .foregroundColor(Color("BackgroundDark"))  // Charcoal, not black
                        
                        Spacer()
                        
                        if !premiumManager.isPremiumUser {
                            PremiumBadge(size: .small)
                        }
                    }
                    
                    Text("7-Day Focused Challenges")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))  // Not .secondary
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(Color("WarmGray"))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)  // Pure white, not off-white
                    .shadow(color: Color("WarmGray").opacity(0.15), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color("WarmGray").opacity(0.1), lineWidth: 1)
                    )
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
                    .foregroundColor(Color("WarmGray"))
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
                activeTab = .profile
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(activeTab == .profile ? Color("PrimaryMain") : Color("WarmGray"))
                    
                    Text("Profile")
                        .font(.caption2)
                        .foregroundColor(activeTab == .profile ? Color("PrimaryMain") : Color("WarmGray"))
                    
                    if activeTab == .profile {
                        Capsule()
                            .fill(Color("PrimaryMain"))
                            .frame(width: 40, height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Activity Button
            Button(action: {
                activeSheet = .analytics
                activeTab = .analytics
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(activeTab == .analytics ? Color("PrimaryMain") : Color("WarmGray"))
                    
                    Text("Activity")
                        .font(.caption2)
                        .foregroundColor(activeTab == .analytics ? Color("PrimaryMain") : Color("WarmGray"))
                    
                    if activeTab == .analytics {
                        Capsule()
                            .fill(Color("PrimaryMain"))
                            .frame(width: 40, height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Settings Button
            Button(action: {
                activeSheet = .settings
                activeTab = .settings
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(activeTab == .settings ? Color("PrimaryMain") : Color("WarmGray"))
                    
                    Text("Settings")
                        .font(.caption2)
                        .foregroundColor(activeTab == .settings ? Color("PrimaryMain") : Color("WarmGray"))
                    
                    if activeTab == .settings {
                        Capsule()
                            .fill(Color("PrimaryMain"))
                            .frame(width: 40, height: 3)
                    }
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
