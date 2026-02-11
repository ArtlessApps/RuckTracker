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
                        feature: .weeklyChallenges,
                        action: {
                            if premiumManager.checkAccess(to: .weeklyChallenges, context: .featureUpsell) {
                                // Navigate to challenges
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
                    .foregroundColor(AppColors.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(feature.description)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Premium Analytics Section
struct PremiumAnalyticsSection: View {
    @ObservedObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Advanced Analytics")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !premiumManager.isPremiumUser {
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
        }
    }
    
    @ViewBuilder
    private var lockedAnalyticsView: some View {
        VStack(spacing: 16) {
            // Show preview charts but disabled
            WeeklyProgressChart()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.shadowBlack)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundColor(AppColors.primary)
                                
                                Text("Premium Analytics")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
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
                .foregroundColor(AppColors.primary.opacity(0.6))
            
            Text("Advanced Analytics")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Get detailed insights into your rucking performance with charts, trends, and personalized recommendations.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
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
                    .foregroundColor(AppColors.textSecondary)
            }
            
            if weeklyData.allSatisfy({ $0.distance == 0 }) {
                // No data state
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("No recent activity")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
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
                                .foregroundColor(AppColors.textSecondary)
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
                            .foregroundColor(AppColors.textSecondary)
                        Text(String(format: "%.1f %@", weeklyData.last?.distance ?? 0, userSettings.preferredDistanceUnit.rawValue))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Avg/Week")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
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

// MARK: - App Store Configuration Helper

struct AppStoreConfiguration {
    // IMPORTANT: These product IDs must match exactly what you create in App Store Connect
    static let monthlySubscriptionID = "com.artless.rucktracker.premium.monthly"
    static let yearlySubscriptionID = "com.artless.rucktracker.premium.yearly"
    
    // Current pricing
    // Monthly: $4.99/month with 7-day free trial
    // Yearly: $39.99/year (33% savings) with 7-day free trial
    
    /*
    App Store Connect Setup Checklist:
    
    1. In App Store Connect:
       - Go to your app
       - Features tab > In-App Purchases
       - Create new Auto-Renewable Subscription Group: "Premium"
       
    2. Create Monthly Subscription:
       - Product ID: com.artless.rucktracker.premium.monthly
       - Reference Name: MARCH Premium Monthly
       - Duration: 1 Month
       - Price: $4.99 USD
       - Free Trial: 7 days
       
    3. Create Yearly Subscription:
       - Product ID: com.artless.rucktracker.premium.yearly
       - Reference Name: MARCH Premium Yearly
       - Duration: 1 Year
       - Price: $39.99 USD
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
    @Binding var isPresentingWorkoutFlow: Bool
    let onDismiss: (() -> Void)?
    @ObservedObject private var programService = LocalProgramService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingConflict = false
    @State private var isEnrolled = false
    @State private var userProgram: UserProgram?
    
    init(program: Program, isPresentingWorkoutFlow: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self.program = program
        self._isPresentingWorkoutFlow = isPresentingWorkoutFlow
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        Group {
            if isEnrolled {
                // Show workouts if enrolled
                ProgramWorkoutsView(
                    userProgram: userProgram,
                    program: program,
                    isPresentingWorkoutFlow: $isPresentingWorkoutFlow,
                    onDismiss: {
                        onDismiss?()
                    }
                )
            } else {
                // Show program info if not enrolled
                programInfoView
            }
        }
        .sheet(isPresented: $showingConflict) {
            if let currentProgram = programService.enrolledProgram,
               let progress = programService.programProgress {
                let workoutCount = WorkoutDataManager.shared.getWorkoutCount(forProgramId: currentProgram.id)
                
                EnrollmentConflictDialog(
                    type: .program,
                    currentName: currentProgram.title,
                    newName: program.title,
                    completedCount: progress.currentWeek - 1,
                    totalCount: currentProgram.durationWeeks,
                    workoutCount: workoutCount,
                    onSwitch: {
                        // Unenroll from current and proceed with new enrollment
                        programService.unenrollFromProgram()
                        showingConflict = false
                        // Enroll in new program directly
                        enrollInProgram()
                    },
                    onCancel: {
                        showingConflict = false
                    }
                )
            }
        }
        .task {
            // Check if user is already enrolled when view appears
            await checkEnrollmentStatus()
        }
    }
    
    private var programInfoView: some View {
        NavigationView {
            ZStack {
                // Background
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(program.title)
                                .font(.system(size: 34, weight: .bold, design: .default))
                                .foregroundColor(AppColors.textPrimary)
                            
                            if let description = program.description {
                                Text(description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(3)
                            }
                            
                            // Difficulty Badge
                            DifficultyBadge(difficulty: program.difficulty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Program Overview Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Program Overview")
                                .font(.system(size: 22, weight: .bold, design: .default))
                                .foregroundColor(AppColors.textPrimary)
                            
                            VStack(spacing: 0) {
                                OverviewItemCard(
                                    icon: "calendar",
                                    title: "Duration",
                                    value: program.durationWeeks > 0 ? "\(program.durationWeeks) weeks" : "Ongoing",
                                    iconColor: .blue,
                                    isFirst: true
                                )
                                
                                OverviewItemCard(
                                    icon: "figure.walk",
                                    title: "Difficulty",
                                    value: program.difficulty.rawValue.capitalized,
                                    iconColor: difficultyIconColor,
                                    isFirst: false
                                )
                                
                                OverviewItemCard(
                                    icon: "target",
                                    title: "Category",
                                    value: program.category.rawValue.capitalized,
                                    iconColor: AppColors.primary,
                                    isFirst: false,
                                    isLast: true
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        
                        // Bottom spacing for button
                        Spacer(minLength: 80)
                    }
                    .padding(.vertical, 12)
                }
                
                // Floating CTA Button
                VStack {
                    Spacer()
                    
                    Button(action: {
                        handleEnrollmentTap()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Enroll in Program")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(16)
                        .shadow(color: AppColors.shadowBlackLight, radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(
                        LinearGradient(
                            colors: [AppColors.surface.opacity(0), AppColors.surface],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .offset(y: 50)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss?()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private func handleEnrollmentTap() {
        // Check for existing enrollment
        if programService.enrolledProgram != nil {
            showingConflict = true
        } else {
            // Skip the enrollment modal and enroll directly
            enrollInProgram()
        }
    }
    
    private func enrollInProgram() {
        programService.enrollInProgram(program)
        
        Task {
            // Reload enrollment status to trigger view transition
            await checkEnrollmentStatus()
        }
    }
    
    private var difficultyIconColor: Color {
        switch program.difficulty {
        case .beginner: return AppColors.accentGreen
        case .intermediate: return .yellow
        case .advanced: return AppColors.primary
        case .elite: return AppColors.primary
        }
    }
    
    private func checkEnrollmentStatus() async {
        // Refresh user programs to get latest enrollment status
        programService.loadUserPrograms()
        
        // Check if user is enrolled in this program
        if let enrolledProgramId = programService.getEnrolledProgramId(),
           enrolledProgramId == program.id {
            isEnrolled = true
            // Load the user program data
            userProgram = programService.userPrograms.first { $0.programId == program.id }
        } else {
            isEnrolled = false
            userProgram = nil
        }
    }
}

// MARK: - Supporting Views
struct DifficultyBadge: View {
    let difficulty: Program.Difficulty
    
    var body: some View {
        Text(difficulty.rawValue.capitalized)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(difficultyColor.opacity(0.2))
            .foregroundColor(difficultyColor)
            .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return AppColors.accentGreen
        case .intermediate: return .yellow
        case .advanced: return AppColors.primary
        case .elite: return AppColors.primary
        }
    }
}

// MARK: - Card Components

struct OverviewItemCard: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Title
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            // Value
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textOnLight)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
        .overlay(
            Group {
                if !isLast {
                    Divider()
                        .padding(.leading, 68)
                        .offset(y: 16)
                }
            }
        )
        .cornerRadius(isFirst ? 16 : 0, corners: [.topLeft, .topRight])
        .cornerRadius(isLast ? 16 : 0, corners: [.bottomLeft, .bottomRight])
        .shadow(color: isFirst ? AppColors.shadowBlackSubtle : .clear, radius: 8, x: 0, y: 2)
    }
}

struct SampleWorkoutCard: View {
    let day: String
    let workout: String
    let icon: String
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
            }
            
            // Day
            Text(day)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textOnLight)
                .frame(width: 90, alignment: .leading)
            
            // Workout
            Text(workout)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
        .overlay(
            Group {
                if !isLast {
                    Divider()
                        .padding(.leading, 68)
                        .offset(y: 16)
                }
            }
        )
        .cornerRadius(isFirst ? 16 : 0, corners: [.topLeft, .topRight])
        .cornerRadius(isLast ? 16 : 0, corners: [.bottomLeft, .bottomRight])
        .shadow(color: isFirst ? AppColors.shadowBlackSubtle : .clear, radius: 8, x: 0, y: 2)
    }
}


struct EnrolledSection: View {
    let userProgram: UserProgram?
    let program: Program
    @State private var showingProgress = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.accentGreen)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enrolled in this program")  // ← MORE LIKE CHALLENGE
                        .fontWeight(.semibold)
                    
                    if let userProgram = userProgram {
                        Text("Week \(userProgram.currentWeek) • \(Int(userProgram.currentWeightLbs)) lbs")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            // Progress button
            Button("View Your Progress") {
                showingProgress = true
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingProgress) {
            ProgramWorkoutsView(
                userProgram: userProgram,
                program: program,
                isPresentingWorkoutFlow: .constant(false),
                onDismiss: nil
            )
        }
    }
}


// MARK: - StatView Component
struct StatView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Program Workouts View (Updated Card Style)
struct ProgramWorkoutsView: View {
    let userProgram: UserProgram?
    let program: Program?
    let onDismiss: (() -> Void)?
    @Binding var isPresentingWorkoutFlow: Bool
    @ObservedObject private var programService = LocalProgramService.shared
    @State private var workouts: [ProgramWorkoutWithState] = []
    @State private var isLoading = true
    @State private var selectedWorkout: ProgramWorkoutWithState?
    @State private var showingLeaveWarning = false
    @State private var selectedWorkoutWeight: Double = UserSettings.shared.defaultRuckWeight
    @EnvironmentObject var workoutManager: WorkoutManager
    
    init(userProgram: UserProgram?, program: Program?, isPresentingWorkoutFlow: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self.userProgram = userProgram
        self.program = program
        self._isPresentingWorkoutFlow = isPresentingWorkoutFlow
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if workouts.isEmpty {
                    emptyStateView
                } else {
                    workoutListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingLeaveWarning = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss?()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .sheet(item: $selectedWorkout) { workout in
                if workout.workout.workoutType == .ruck && !workout.isCompleted && !workout.isLocked {
                    // Ruck workout ready to start → use unified weight selector
                    WorkoutWeightSelector(
                        selectedWeight: $selectedWorkoutWeight,
                        isPresented: Binding(
                            get: { selectedWorkout != nil },
                            set: { if !$0 { selectedWorkout = nil } }
                        ),
                        recommendedWeight: userProgram?.currentWeightLbs,
                        context: workout.displayTitle,
                        subtitle: "Day \(workout.workout.dayNumber) • Week \(workout.weekNumber)",
                        instructions: workout.workout.instructions,
                        onStart: {
                            startProgramWorkout(workout)
                        }
                    )
                    .onAppear {
                        // Initialize weight for this workout
                        let initialWeight = userProgram?.currentWeightLbs ?? UserSettings.shared.defaultRuckWeight
                        selectedWorkoutWeight = max(initialWeight, UserSettings.shared.defaultRuckWeight)
                    }
                } else {
                    // Rest day, completed, or non-ruck → show detail view
                    WorkoutDetailView(
                        workout: workout,
                        programId: program?.id,
                        userProgram: userProgram,
                        onComplete: {
                            Task {
                                await loadWorkouts()
                            }
                        },
                        isPresentingWorkoutFlow: $isPresentingWorkoutFlow,
                        onDismiss: onDismiss
                    )
                    .environmentObject(workoutManager)
                }
            }
            .sheet(isPresented: $showingLeaveWarning) {
                if let program = program,
                   let progress = programService.programProgress {
                    let workoutCount = WorkoutDataManager.shared.getWorkoutCount(forProgramId: program.id)
                    
                    LeaveWarningDialog(
                        type: .program,
                        name: program.title,
                        completedCount: progress.currentWeek - 1,
                        totalCount: program.durationWeeks,
                        workoutCount: workoutCount,
                        onLeave: {
                            leaveProgram()
                        },
                        onCancel: {
                            showingLeaveWarning = false
                        }
                    )
                }
            }
            .task {
                await loadWorkouts()
            }
        }
    }
    
    private func leaveProgram() {
        // Unenroll from the program
        programService.unenrollFromProgram()
        showingLeaveWarning = false
        onDismiss?()
    }
    
    private func startProgramWorkout(_ workout: ProgramWorkoutWithState) {
        // Set the weight in workout manager
        workoutManager.ruckWeight = selectedWorkoutWeight
        
        // Provide program context so the save is tagged
        let resolvedProgramId = program?.id
            ?? userProgram?.programId
            ?? LocalProgramService.shared.getEnrolledProgramId()
            ?? (UUID(uuidString: UserSettings.shared.activeProgramID ?? ""))
        let resolvedDay = workout.workout.dayNumber
        print("📌 ProgramWorkoutsView startWorkout resolvedProgramId=\(resolvedProgramId?.uuidString ?? "nil") day=\(resolvedDay)")
        workoutManager.setProgramContext(programId: resolvedProgramId, day: resolvedDay)
        
        // Start the workout
        workoutManager.startWorkout(weight: selectedWorkoutWeight)
        
        // Trigger the workout flow presentation
        isPresentingWorkoutFlow = true
    }
    
    // MARK: - Subviews
    
    private var workoutListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Progress Header Card
                progressHeader
                
                // Workout Cards
                LazyVStack(spacing: 12) {
                    ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                        WorkoutRowView(
                            workout: workout,
                            index: index + 1
                        )
                        .onTapGesture {
                            if !workout.isLocked {
                                selectedWorkout = workout
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .padding(.vertical, 12)
        }
    }
    
    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(program?.title ?? "Program")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\(completedCount) of \(workouts.count) workouts")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: progressPercentage)
                        .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                    
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading workouts...")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No Workouts Found")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("This program doesn't have any workouts yet.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Computed Properties
    
    private var completedCount: Int {
        guard let program = program else { return 0 }
        return ProgramProgressCalculator.getCompletedCount(for: program)
    }
    
    private var progressPercentage: Double {
        guard let program = program else { return 0 }
        return ProgramProgressCalculator.calculateProgress(for: program)
    }
    
    // MARK: - Methods
    
    private func loadWorkouts() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let program = program else {
            print("❌ No program provided")
            return
        }
        
        do {
            // Load workouts from local service
            let programWorkouts = try await programService.loadProgramWorkouts(programId: program.id)
            
            // Load weeks to resolve weekId -> weekNumber
            let weeks = programService.getProgramWeeks(programId: program.id)
            let weekNumberByID: [UUID: Int] = Dictionary(
                uniqueKeysWithValues: weeks.map { ($0.id, $0.weekNumber) }
            )
            
            // Get completions from CoreData (via local service)
            let completedWorkoutIndices = WorkoutDataManager.shared.workouts
                .filter { $0.programId == program.id.uuidString }
                .compactMap { Int($0.programWorkoutDay) - 1 } // Convert to 0-based index
            
            // Map workouts to state
            var lastCompletedIndex = -1
            
            workouts = programWorkouts.enumerated().map { index, workout in
                let isCompleted = completedWorkoutIndices.contains(index)
                
                if isCompleted {
                    lastCompletedIndex = index
                }
                
                // Unlock logic: first workout unlocked, rest unlock after previous completion
                let isLocked: Bool
                if workout.workoutType == .rest {
                    isLocked = false
                } else {
                    isLocked = index > lastCompletedIndex + 1
                }
                
                // Resolve actual week number from the program's week data
                let resolvedWeekNumber = weekNumberByID[workout.weekId] ?? 1
                
                return ProgramWorkoutWithState(
                    workout: workout,
                    weekNumber: resolvedWeekNumber,
                    isCompleted: isCompleted,
                    isLocked: isLocked,
                    completionDate: nil
                )
            }
        } catch {
            print("❌ Error loading workouts: \(error)")
        }
    }
}

// MARK: - Workout Row View (Updated Card Style)
struct WorkoutRowView: View {
    let workout: ProgramWorkoutWithState
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Numbered Badge (Icon-less)
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                if workout.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(statusColor)
                } else if workout.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(statusColor)
                } else {
                    Text("\(index)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(statusColor)
                }
            }
            
            // Workout Details
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.displayTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(workout.isLocked ? AppColors.textSecondary.opacity(0.5) : AppColors.textPrimary)
                
                Text(workout.displaySubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(workout.isLocked ? AppColors.textSecondary.opacity(0.4) : AppColors.textSecondary)
                
                if let instructions = workout.workout.instructions?.prefix(50) {
                    Text(String(instructions) + "...")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Status Icon
            if !workout.isCompleted && !workout.isLocked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            workout.isLocked ? AppColors.textSecondary.opacity(0.1) : AppColors.textSecondary.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
        .opacity(workout.isLocked ? 0.5 : 1.0)
    }
    
    private var statusColor: Color {
        if workout.isCompleted {
            return AppColors.accentGreen
        } else if workout.isLocked {
            return AppColors.textSecondary
        } else if workout.workout.workoutType == .rest {
            return AppColors.accentTeal
        } else {
            return AppColors.primary
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    Color.blue,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Workout Detail View (Rest Day / Completed States)
struct WorkoutDetailView: View {
    let workout: ProgramWorkoutWithState
    let programId: UUID?
    let userProgram: UserProgram?
    let onComplete: () -> Void
    @Binding var isPresentingWorkoutFlow: Bool
    let onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var programService = LocalProgramService.shared
    @State private var isCompleting = false
    @State private var showingCompletionConfirmation = false
    
    init(workout: ProgramWorkoutWithState, programId: UUID?, userProgram: UserProgram?, onComplete: @escaping () -> Void, isPresentingWorkoutFlow: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self.workout = workout
        self.programId = programId
        self.userProgram = userProgram
        self.onComplete = onComplete
        self._isPresentingWorkoutFlow = isPresentingWorkoutFlow
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Top section with context
                    VStack(spacing: 8) {
                        Text(workout.displayTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Day \(workout.workout.dayNumber) • Week \(workout.weekNumber)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.bottom, 40)
                    
                    // Content based on state
                    if workout.isCompleted {
                        completedSection
                    } else {
                        restDaySection
                    }
                    
                    Spacer()
                        .frame(minHeight: 20)
                    
                    // Instructions at bottom
                    if let instructions = workout.workout.instructions {
                        instructionsSection(instructions)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    actionButtons
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert("Mark as Complete?", isPresented: $showingCompletionConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Complete") {
                    Task {
                        await completeWorkout()
                    }
                }
            } message: {
                Text("Mark this workout as completed and unlock the next workout.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var completedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.accentGreen)
            
            Text("Completed")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Great work!")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 40)
    }
    
    private var restDaySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.accentTeal)
            
            Text("Rest Day")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Recovery is essential")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 40)
    }
    
    private func instructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.primary)
                
                Text("Instructions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(instructions)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surfaceAlt.opacity(0.5))
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            if workout.isCompleted {
                // Completed state - just close button
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Completed")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accentGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.accentGreen.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            } else if !workout.isLocked && workout.workout.workoutType == .rest {
                // Rest day - mark complete
                Button(action: {
                    showingCompletionConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16))
                        Text("Mark Complete")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.primaryGradient)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
    
    // MARK: - Methods
    
    private func completeWorkout() async {
        isCompleting = true
        defer { isCompleting = false }
        
        // Record the completion in CoreData
        let weight = userProgram?.currentWeightLbs ?? UserSettings.shared.defaultRuckWeight
        WorkoutDataManager.shared.saveWorkout(
            date: Date(),
            duration: 0,
            distance: workout.workout.distanceMiles ?? 0,
            calories: 0,
            ruckWeight: weight,
            heartRate: 0,
            programId: programId ?? userProgram?.programId,
            programWorkoutDay: workout.workout.dayNumber,
            challengeId: nil,
            challengeDay: nil
        )
        
        // Refresh program progress
        programService.refreshProgramProgress()
        
        // Call the completion handler to refresh the list
        onComplete()
        
        // Dismiss the view
        dismiss()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Old Progress Supporting Views (keeping for compatibility)
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
                    color: AppColors.primary
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
                    .foregroundColor(AppColors.textPrimary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
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
                    .foregroundColor(AppColors.textSecondary)
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
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.accentGreen)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(AppColors.textSecondary)
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
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(weight)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(duration)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rounded Corner Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
