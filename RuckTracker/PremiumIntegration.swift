import SwiftUI

// MARK: - Updated Settings View with Premium Integration

struct UpdatedSettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var healthManager: HealthManager
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                // Premium Status Section
                Section {
                    PremiumStatusView()
                }
                
                // Free trial banner (shows if in trial)
                FreeTrialBanner()
                
                // Body Weight Section
                Section(header: Text("Body Weight"), footer: Text("Used for accurate calorie calculations")) {
                    // ... existing body weight content
                }
                
                // Premium Features Section
                Section("Premium Features") {
                    PremiumFeatureRow(
                        feature: .trainingPrograms,
                        action: {
                            // Navigate to programs or show paywall
                            if premiumManager.checkAccess(to: .trainingPrograms, context: .programAccess) {
                                // Navigate to training programs
                            }
                        }
                    )
                    
                    PremiumFeatureRow(
                        feature: .advancedAnalytics,
                        action: {
                            if premiumManager.checkAccess(to: .advancedAnalytics, context: .featureUpsell) {
                                // Navigate to analytics
                            }
                        }
                    )
                    
                    PremiumFeatureRow(
                        feature: .exportData,
                        action: {
                            if premiumManager.checkAccess(to: .exportData, context: .featureUpsell) {
                                // Show export options
                            }
                        }
                    )
                }
                
                // ... rest of existing sections
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $premiumManager.showingPaywall) {
                SubscriptionPaywallView(context: premiumManager.paywallContext)
            }
        }
    }
}

struct PremiumFeatureRow: View {
    let feature: PremiumFeature
    let action: () -> Void
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: feature.iconName)
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(feature.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if premiumManager.requiresPremium(for: feature) {
                    PremiumBadge(size: .small)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Updated Phone Main View with Premium Features

struct UpdatedPhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var premiumManager = PremiumManager.shared
    @State private var showingSettings = false
    @State private var showingPremiumPrograms = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Free trial banner at top if applicable
                    FreeTrialBanner()
                    
                    AppleWatchHeroSection()
                    
                    // Premium Training Programs Section
                    PremiumTrainingProgramsSection()
                    
                    if !workoutDataManager.workouts.isEmpty {
                        QuickStatsDashboard()
                            .environmentObject(workoutDataManager)
                    }
                    
                    RecentActivitySection()
                        .environmentObject(workoutDataManager)
                    
                    // Premium Analytics Section (gated)
                    PremiumAnalyticsSection()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("RuckTracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            UpdatedSettingsView()
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
    }
}

// MARK: - Premium Training Programs Section

struct PremiumTrainingProgramsSection: View {
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Training Programs")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                PremiumBadge(size: .small)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ProgramCard(
                    title: "Military Foundation",
                    description: "8-week program for beginners",
                    difficulty: "Beginner",
                    weeks: 8
                )
                
                ProgramCard(
                    title: "Ranger Challenge",
                    description: "Advanced 12-week training",
                    difficulty: "Advanced", 
                    weeks: 12
                )
            }
        }
        .premiumGated(for: .trainingPrograms, context: .programAccess)
    }
}

struct ProgramCard: View {
    let title: String
    let description: String
    let difficulty: String
    let weeks: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label(difficulty, systemImage: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text("\(weeks)w")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

// MARK: - Premium Analytics Section

struct PremiumAnalyticsSection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Advanced Analytics")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                PremiumBadge(size: .small)
            }
            
            if workoutDataManager.workouts.isEmpty {
                AnalyticsEmptyState()
            } else {
                VStack(spacing: 16) {
                    WeeklyProgressChart()
                    PerformanceInsightsCard()
                }
            }
        }
        .premiumGated(for: .advancedAnalytics, context: .featureUpsell)
    }
}

struct AnalyticsEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.orange.opacity(0.6))
            
            Text("Advanced Analytics")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Get detailed insights into your rucking performance with charts, trends, and personalized recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

struct WeeklyProgressChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Progress")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Placeholder chart
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .frame(height: 120)
                .overlay(
                    Text("Weekly Distance Chart")
                        .foregroundColor(.blue)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct PerformanceInsightsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Performance Insights")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InsightRow(
                    icon: "arrow.up.circle.fill",
                    text: "Your pace has improved 12% this month",
                    color: .green
                )
                
                InsightRow(
                    icon: "target",
                    text: "You're ready to increase ruck weight by 5 lbs",
                    color: .orange
                )
                
                InsightRow(
                    icon: "calendar.badge.plus",
                    text: "Add one more ruck per week for optimal progression",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - App Store Configuration Helper

struct AppStoreConfiguration {
    // IMPORTANT: These product IDs must match exactly what you create in App Store Connect
    static let monthlySubscriptionID = "com.artless.rucktracker.premium.monthly"
    static let yearlySubscriptionID = "com.artless.rucktracker.premium.yearly"
    
    // Suggested pricing (you set this in App Store Connect)
    // Monthly: $4.99/month
    // Yearly: $39.99/year (33% savings)
    
    /*
    App Store Connect Setup Checklist:
    
    1. In App Store Connect:
       - Go to your app
       - Features tab > In-App Purchases
       - Create new Auto-Renewable Subscription Group: "Premium"
       
    2. Create Monthly Subscription:
       - Product ID: com.artless.rucktracker.premium.monthly
       - Reference Name: RuckTracker Premium Monthly
       - Duration: 1 Month
       - Price: $4.99 (or equivalent in your currency)
       - Free Trial: 7 days
       
    3. Create Yearly Subscription:
       - Product ID: com.artless.rucktracker.premium.yearly  
       - Reference Name: RuckTracker Premium Yearly
       - Duration: 1 Year
       - Price: $39.99 (or equivalent)
       - Free Trial: 7 days
       
    4. Set up Subscription Group:
       - Add both subscriptions to the same group
       - Configure subscription levels (yearly higher than monthly)
       
    5. Add Localizations:
       - Provide names and descriptions in your supported languages
       
    6. Submit for Review:
       - Both subscriptions need App Store approval
       - Include app screenshots showing premium features
       - Provide a demo account for reviewers
    */
}
