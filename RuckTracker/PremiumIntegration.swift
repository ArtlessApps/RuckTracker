import SwiftUI
import Foundation

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

// MARK: - Updated Program Cards with Navigation
struct PremiumTrainingProgramsSection: View {
    @EnvironmentObject var premiumManager: PremiumManager
    private let programService = ProgramService.shared
    @State private var selectedProgram: Program?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Training Programs")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !premiumManager.isPremiumUser {
                    PremiumBadge(size: .small)
                }
            }
            
            if premiumManager.isPremiumUser {
                activeProgramsView
            } else {
                lockedProgramsView
            }
        }
        .sheet(item: $selectedProgram) { program in
            ProgramDetailView(program: program)
                .environmentObject(programService)
        }
        .task {
            // Load programs when view appears (for premium users)
            if premiumManager.isPremiumUser {
                do {
                    await programService.loadPrograms()
                } catch {
                    print("Failed to load programs: \(error)")
                }
            }
        }
    }
    
    @ViewBuilder
    private var activeProgramsView: some View {
        if programService.isLoading {
            ProgressView("Loading programs...")
                .frame(maxWidth: .infinity)
                .padding()
        } else if programService.programs.isEmpty {
            Text("No programs available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(programService.programs) { program in
                    FunctionalProgramCard(
                        title: program.title,
                        description: program.description ?? "Training program",
                        difficulty: program.difficulty.rawValue.capitalized,
                        weeks: program.durationWeeks,
                        isLocked: false
                    ) {
                        selectedProgram = program
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var lockedProgramsView: some View {
        if programService.isLoading {
            ProgressView("Loading programs...")
                .frame(maxWidth: .infinity)
                .padding()
        } else if programService.programs.isEmpty {
            Text("No programs available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(programService.programs.filter { $0.category != .fitness }) { program in
                    FunctionalProgramCard(
                        title: program.title,
                        description: program.description ?? "Training program",
                        difficulty: program.difficulty.rawValue.capitalized,
                        weeks: program.durationWeeks,
                        isLocked: true
                    ) {
                        premiumManager.showPaywall(context: .programAccess)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                            
                            Text("Premium Feature")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Tap to unlock training programs")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            )
        }
    }
    
}

// MARK: - Functional Program Card
struct FunctionalProgramCard: View {
    let title: String
    let description: String
    let difficulty: String
    let weeks: Int
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(isLocked ? .secondary : .primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label(difficulty, systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundColor(isLocked ? .secondary : .orange)
                    
                    Spacer()
                    
                    if weeks > 0 {
                        Text("\(weeks)w")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ongoing")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isLocked {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(isLocked ? 0.03 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isLocked ? Color.orange.opacity(0.3) : Color.blue.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Analytics Section
struct PremiumAnalyticsSection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Advanced Analytics")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !premiumManager.isPremiumUser {
                    PremiumBadge(size: .small)
                }
            }
            
            if premiumManager.isPremiumUser {
                if workoutDataManager.workouts.isEmpty {
                    AnalyticsEmptyState()
                } else {
                    activeAnalyticsView
                }
            } else {
                lockedAnalyticsView
            }
        }
        .onTapGesture {
            if !premiumManager.isPremiumUser {
                premiumManager.showPaywall(context: .featureUpsell)
            }
        }
    }
    
    @ViewBuilder
    private var activeAnalyticsView: some View {
        VStack(spacing: 16) {
            WeeklyProgressChart()
            PerformanceInsightsCard()
        }
    }
    
    @ViewBuilder
    private var lockedAnalyticsView: some View {
        VStack(spacing: 16) {
            // Show preview charts but disabled
            WeeklyProgressChart()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                
                                Text("Premium Analytics")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Detailed charts and insights")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                )
        }
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
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    private var weeklyData: [WeeklyDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        
        // Get last 8 weeks of data
        var weeks: [WeeklyDataPoint] = []
        
        for i in 0..<8 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: today) ?? today
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
            
            let weekWorkouts = workoutDataManager.workouts.filter { workout in
                guard let workoutDate = workout.date else { return false }
                return workoutDate >= weekStart && workoutDate <= weekEnd
            }
            
            let totalDistance = weekWorkouts.reduce(0) { $0 + $1.distance }
            let displayDistance = userSettings.preferredDistanceUnit == .miles ? 
                totalDistance : 
                totalDistance / userSettings.preferredDistanceUnit.conversionToMiles
            
            weeks.append(WeeklyDataPoint(
                weekStart: weekStart,
                distance: displayDistance,
                workoutCount: weekWorkouts.count
            ))
        }
        
        return weeks.reversed() // Show oldest to newest
    }
    
    private var maxDistance: Double {
        weeklyData.map(\.distance).max() ?? 1.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("Last 8 weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if weeklyData.allSatisfy({ $0.distance == 0 }) {
                // No data state
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("No recent activity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            } else {
                // Chart with data
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeklyData.indices, id: \.self) { index in
                        let dataPoint = weeklyData[index]
                        let height = maxDistance > 0 ? (dataPoint.distance / maxDistance) * 100 : 0
                        
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dataPoint.distance > 0 ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 20, height: max(height, 4))
                                .animation(.easeInOut(duration: 0.3), value: height)
                            
                            // Week label
                            Text(weekLabel(for: dataPoint.weekStart))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(-45))
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Summary stats
            if !weeklyData.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This Week")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f %@", weeklyData.last?.distance ?? 0, userSettings.preferredDistanceUnit.rawValue))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Avg/Week")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f %@", weeklyData.map(\.distance).reduce(0, +) / Double(weeklyData.count), userSettings.preferredDistanceUnit.rawValue))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private func weekLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct WeeklyDataPoint {
    let weekStart: Date
    let distance: Double
    let workoutCount: Int
}

struct PerformanceInsightsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                
                Text("Performance Insights")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InsightRow(
                    icon: "arrow.up.circle.fill",
                    text: "Pace improving by 5% over last month",
                    color: .green
                )
                
                InsightRow(
                    icon: "target",
                    text: "Recommended: Increase ruck weight by 5lbs",
                    color: .blue
                )
                
                InsightRow(
                    icon: "calendar",
                    text: "3 days since last workout - consider scheduling",
                    color: .orange
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
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

// MARK: - Program Detail View
struct ProgramDetailView: View {
    let program: Program
    @EnvironmentObject var programService: ProgramService
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
    @State private var isEnrolled = false
    @State private var userProgram: UserProgram?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(program.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let description = program.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            DifficultyBadge(difficulty: program.difficulty)
                            
                            Spacer()
                            
                            if program.durationWeeks > 0 {
                                Text("\(program.durationWeeks) weeks")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Program Overview
                    ProgramOverviewSection(program: program)
                    
                    // Sample Week Preview
                    SampleWeekSection()
                    
                    // Enrollment Section
                    if !isEnrolled {
                        EnrollmentSection {
                            showingEnrollment = true
                        }
                    } else {
                        EnrolledSection(userProgram: userProgram)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEnrollment) {
            ProgramEnrollmentView(program: program) { startingWeight in
                enrollInProgram(startingWeight: startingWeight)
            }
        }
        .task {
            // Check if user is already enrolled when view appears
            await checkEnrollmentStatus()
        }
    }
    
    private func enrollInProgram(startingWeight: Double) {
        Task {
            do {
                try await programService.enrollInProgram(program, startingWeight: startingWeight)
                await MainActor.run {
                    // Check enrollment status again to get the new UserProgram
                    Task {
                        await checkEnrollmentStatus()
                    }
                    showingEnrollment = false
                }
            } catch {
                print("Failed to enroll in program: \(error)")
            }
        }
    }
    
    private func checkEnrollmentStatus() async {
        // Check if user is enrolled in this specific program
        let enrolled = programService.userPrograms.contains { userProg in
            userProg.programId == program.id && userProg.isActive
        }
        
        let currentUserProgram = programService.userPrograms.first { userProg in
            userProg.programId == program.id && userProg.isActive
        }
        
        await MainActor.run {
            self.isEnrolled = enrolled
            self.userProgram = currentUserProgram
        }
    }
}

// MARK: - Supporting Views
struct DifficultyBadge: View {
    let difficulty: Program.Difficulty
    
    var body: some View {
        Text(difficulty.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difficultyColor.opacity(0.2))
            .foregroundColor(difficultyColor)
            .cornerRadius(6)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .yellow
        case .advanced: return .orange
        case .elite: return .red
        }
    }
}

struct ProgramOverviewSection: View {
    let program: Program
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Program Overview")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                OverviewItem(
                    icon: "calendar",
                    title: "Duration",
                    value: program.durationWeeks > 0 ? "\(program.durationWeeks) weeks" : "Ongoing"
                )
                
                OverviewItem(
                    icon: "figure.walk",
                    title: "Difficulty",
                    value: program.difficulty.rawValue.capitalized
                )
                
                OverviewItem(
                    icon: "target",
                    title: "Category",
                    value: program.category.rawValue.capitalized
                )
            }
        }
    }
}

struct OverviewItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct SampleWeekSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sample Week")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                SampleWorkoutRow(day: "Monday", workout: "3 mile ruck @ 25lbs")
                SampleWorkoutRow(day: "Tuesday", workout: "Rest day")
                SampleWorkoutRow(day: "Wednesday", workout: "5 mile ruck @ 25lbs")
                SampleWorkoutRow(day: "Thursday", workout: "Cross training")
                SampleWorkoutRow(day: "Friday", workout: "4 mile ruck @ 30lbs")
                SampleWorkoutRow(day: "Weekend", workout: "Long ruck or rest")
            }
        }
    }
}

struct SampleWorkoutRow: View {
    let day: String
    let workout: String
    
    var body: some View {
        HStack {
            Text(day)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(workout)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct EnrollmentSection: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: action) {
                Text("Start This Program")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            
            Text("You'll be able to track your progress and adjust weight as you advance through the program.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct EnrolledSection: View {
    let userProgram: UserProgram?
    @State private var showingProgress = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Program")
                        .fontWeight(.semibold)
                    if let userProgram = userProgram {
                        Text("Week \(userProgram.currentWeek) • \(Int(userProgram.currentWeightLbs)) lbs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            Button("View Your Progress") {
                showingProgress = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showingProgress) {
            ProgramProgressView(userProgram: userProgram)
        }
    }
}

// MARK: - Program Enrollment View
struct ProgramEnrollmentView: View {
    let program: Program
    let onEnroll: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startingWeight: Double = 20
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Start Your Program")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose your starting ruck weight. You can adjust this as you progress through the program.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 24) {
                    Text("Starting Ruck Weight")
                        .font(.headline)
                    
                    VStack {
                        Text("\(Int(startingWeight)) lbs")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        Slider(value: $startingWeight, in: 5...50, step: 5)
                            .accentColor(.orange)
                    }
                    
                    Text("Recommended: 15-20% of body weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        onEnroll(startingWeight)
                    } label: {
                        Text("Start Program")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Program Progress View
struct ProgramProgressView: View {
    let userProgram: UserProgram?
    @Environment(\.dismiss) private var dismiss
    
    private var currentWeek: Int {
        userProgram?.currentWeek ?? 1
    }
    
    private var currentWeight: Double {
        userProgram?.currentWeightLbs ?? 25.0
    }
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Progress Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Progress")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Military Foundation Program")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress Stats
                    ProgressStatsSection(
                        currentWeek: currentWeek,
                        currentWeight: currentWeight
                    )
                    
                    // Weekly Progress
                    WeeklyProgressSection(currentWeek: currentWeek)
                    
                    // Weight Progression
                    WeightProgressionSection(currentWeight: currentWeight)
                    
                    // Recent Workouts
                    RecentWorkoutsSection()
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Progress Supporting Views
struct ProgressStatsSection: View {
    let currentWeek: Int
    let currentWeight: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Overview")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ProgressStatCard(
                    title: "Current Week",
                    value: "\(currentWeek)",
                    subtitle: "of 8 weeks",
                    icon: "calendar",
                    color: .blue
                )
                
                ProgressStatCard(
                    title: "Current Weight",
                    value: "\(Int(currentWeight)) lbs",
                    subtitle: "ruck weight",
                    icon: "backpack.fill",
                    color: .orange
                )
            }
        }
    }
}

struct ProgressStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct WeeklyProgressSection: View {
    let currentWeek: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week's Plan")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                WeeklyWorkoutRow(day: "Monday", workout: "3 mile ruck @ 25lbs", isCompleted: true)
                WeeklyWorkoutRow(day: "Tuesday", workout: "Rest day", isCompleted: true)
                WeeklyWorkoutRow(day: "Wednesday", workout: "5 mile ruck @ 25lbs", isCompleted: false)
                WeeklyWorkoutRow(day: "Thursday", workout: "Cross training", isCompleted: false)
                WeeklyWorkoutRow(day: "Friday", workout: "4 mile ruck @ 30lbs", isCompleted: false)
                WeeklyWorkoutRow(day: "Weekend", workout: "Long ruck or rest", isCompleted: false)
            }
        }
    }
}

struct WeeklyWorkoutRow: View {
    let day: String
    let workout: String
    let isCompleted: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(day)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct WeightProgressionSection: View {
    let currentWeight: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weight Progression")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                WeightProgressionRow(week: 1, weight: 20.0, isCompleted: true)
                WeightProgressionRow(week: 2, weight: 22.0, isCompleted: true)
                WeightProgressionRow(week: 3, weight: 25.0, isCompleted: true)
                WeightProgressionRow(week: 4, weight: 25.0, isCompleted: false)
                WeightProgressionRow(week: 5, weight: 28.0, isCompleted: false)
            }
        }
    }
}

struct WeightProgressionRow: View {
    let week: Int
    let weight: Double
    let isCompleted: Bool
    
    var body: some View {
        HStack {
            Text("Week \(week)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            
            Text("\(Int(weight)) lbs")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecentWorkoutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Workouts")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                RecentWorkoutRow(date: "Today", workout: "3 mile ruck", weight: "25 lbs", duration: "45 min")
                RecentWorkoutRow(date: "Yesterday", workout: "Rest day", weight: "0 lbs", duration: "0 min")
                RecentWorkoutRow(date: "2 days ago", workout: "5 mile ruck", weight: "22 lbs", duration: "1h 15m")
            }
        }
    }
}

struct RecentWorkoutRow: View {
    let date: String
    let workout: String
    let weight: String
    let duration: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(weight)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(duration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
