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
    @Binding var isPresentingWorkoutFlow: Bool
    let onDismiss: (() -> Void)?
    @ObservedObject private var programService = LocalProgramService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
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
        .sheet(isPresented: $showingEnrollment, onDismiss: {
            // Re-check enrollment status when sheet dismisses
            Task {
                await checkEnrollmentStatus()
            }
        }) {
            ProgramEnrollmentView(program: program) {
                enrollInProgram()
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
                        showingEnrollment = true
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
                    EnrollmentSection {
                        handleEnrollmentTap()
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
    }
    
    private func handleEnrollmentTap() {
        // Check for existing enrollment
        if programService.enrolledProgram != nil {
            showingConflict = true
        } else {
            showingEnrollment = true
        }
    }
    
    private func enrollInProgram() {
        programService.enrollInProgram(program)
        
        Task {
            await MainActor.run {
                showingEnrollment = false
                // Reload enrollment status
                Task {
                    await checkEnrollmentStatus()
                }
            }
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
        VStack(spacing: 12) {
            Button(action: action) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Enroll in Program")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            
            Text("You can adjust your weight anytime during the program")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
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
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enrolled in this program")  // ← MORE LIKE CHALLENGE
                        .fontWeight(.semibold)
                    
                    if let userProgram = userProgram {
                        Text("Week \(userProgram.currentWeek) • \(Int(userProgram.currentWeightLbs)) lbs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
            .foregroundColor(.white)
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

// MARK: - Program Enrollment View
struct ProgramEnrollmentView: View {
    let program: Program
    let onEnroll: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        // Challenge Info Header
                        challengeHeaderView
                        
                        // Enrollment Button
                        enrollmentButtonView
                        
                        // Extra padding to ensure button is visible
                        Color.clear.frame(height: 50)
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height)
                }
            }
            .navigationTitle("Enroll in Program")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Views
    
    private var challengeHeaderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text(program.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if let description = program.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Program stats
            HStack(spacing: 20) {
                StatView(
                    icon: "calendar",
                    title: "Duration",
                    value: "\(program.durationWeeks) weeks"
                )
                
                StatView(
                    icon: "star.fill",
                    title: "Difficulty",
                    value: program.difficulty.rawValue.capitalized
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    
    private var enrollmentButtonView: some View {
        VStack(spacing: 12) {
            Button(action: { onEnroll() }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Enroll in Program")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            
            Text("You can adjust your weight anytime during the program")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Program Workouts View (Peloton-style)
struct ProgramWorkoutsView: View {
    let userProgram: UserProgram?
    let program: Program?
    let onDismiss: (() -> Void)?
    @Binding var isPresentingWorkoutFlow: Bool
    @ObservedObject private var programService = LocalProgramService.shared
    @State private var workouts: [ProgramWorkoutWithState] = []
    @State private var isLoading = true
    @State private var selectedWorkout: ProgramWorkoutWithState?
    @State private var showingWorkoutDetail = false
    @State private var showingLeaveWarning = false
    
    init(userProgram: UserProgram?, program: Program?, isPresentingWorkoutFlow: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self.userProgram = userProgram
        self.program = program
        self._isPresentingWorkoutFlow = isPresentingWorkoutFlow
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading workouts...")
                } else if workouts.isEmpty {
                    emptyStateView
                } else {
                    workoutListView
                }
            }
            .navigationTitle(program?.title ?? "Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLeaveWarning = true
                    } label: {
                        Label("Leave", systemImage: "xmark.circle")
                            .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss?()
                    }
                }
            }
            .sheet(isPresented: $isPresentingWorkoutFlow) {
                if let workout = selectedWorkout {
                    WorkoutDetailView(
                        workout: workout,
                        userProgram: userProgram,
                        onComplete: {
                            Task {
                                await loadWorkouts()
                            }
                        },
                        isPresentingWorkoutFlow: $isPresentingWorkoutFlow,
                        onDismiss: onDismiss
                    )
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
        }
        .task {
            await loadWorkouts()
        }
    }
    
    private func leaveProgram() {
        // Unenroll from the program
        programService.unenrollFromProgram()
        showingLeaveWarning = false
        onDismiss?()
    }
    
    private var workoutListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Progress header
                progressHeader
                
                // Workout list
                LazyVStack(spacing: 0) {
                    ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                        WorkoutRowView(
                            workout: workout,
                            index: index + 1
                        )
                        .onTapGesture {
                            if !workout.isLocked {
                                selectedWorkout = workout
                                isPresentingWorkoutFlow = true
                            }
                        }
                        
                        if index < workouts.count - 1 {
                            Divider()
                                .padding(.leading, 80)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var progressHeader: some View {
        VStack(spacing: 12) {
            // Overall progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program?.title ?? "Program")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(completedCount) of \(workouts.count) workouts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(
                    progress: progressPercentage,
                    lineWidth: 8
                )
                .frame(width: 60, height: 60)
            }
            
            // Progress bar
            ProgressView(value: progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Workouts Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This program doesn't have any workouts yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var completedCount: Int {
        workouts.filter { $0.isCompleted }.count
    }
    
    private var progressPercentage: Double {
        guard !workouts.isEmpty else { return 0 }
        return Double(completedCount) / Double(workouts.count)
    }
    
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
            
            // Get completions from CoreData (via local service)
            // NOTE: programWorkoutDay in CoreData is the SEQUENTIAL workout number (1, 2, 3...),
            // NOT the day_number within each week. We need to match by index in the workout list.
            let completedWorkoutIndices = WorkoutDataManager.shared.workouts
                .filter { $0.programId == program.id.uuidString }
                .compactMap { Int($0.programWorkoutDay) - 1 } // Convert to 0-based index
            
            print("🔍 UI DEBUG: Program ID: \(program.id.uuidString)")
            print("🔍 UI DEBUG: Total workouts in CoreData: \(WorkoutDataManager.shared.workouts.count)")
            print("🔍 UI DEBUG: Workouts for this program: \(WorkoutDataManager.shared.workouts.filter { $0.programId == program.id.uuidString }.count)")
            print("🔍 UI DEBUG: Completed workout indices: \(completedWorkoutIndices)")
            
            // Map workouts to state
            var lastCompletedIndex = -1
            
            workouts = programWorkouts.enumerated().map { index, workout in
                let isCompleted = completedWorkoutIndices.contains(index)
                
                if isCompleted {
                    lastCompletedIndex = index
                    print("🔍 UI DEBUG: Workout index \(index) (day \(workout.dayNumber)) marked as completed")
                }
                
                // Unlock logic: first workout unlocked, rest unlock after previous completion
                let isLocked: Bool
                if workout.workoutType == .rest {
                    isLocked = false
                } else {
                    isLocked = index > lastCompletedIndex + 1
                }
                
                return ProgramWorkoutWithState(
                    workout: workout,
                    weekNumber: (workout.dayNumber - 1) / 7 + 1,
                    isCompleted: isCompleted,
                    isLocked: isLocked,
                    completionDate: nil
                )
            }
            
            print("✅ Loaded \(workouts.count) workouts, \(completedWorkoutIndices.count) completed")
        } catch {
            print("❌ Error loading workouts: \(error)")
        }
    }
}

// MARK: - Workout Row View (Peloton-style)
struct WorkoutRowView: View {
    let workout: ProgramWorkoutWithState
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                if workout.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                } else if workout.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                } else {
                    Text("\(index)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                }
            }
            
            // Middle: Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.displayTitle)
                    .font(.headline)
                    .foregroundColor(workout.isLocked ? .secondary : .primary)
                
                Text(workout.displaySubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let instructions = workout.workout.instructions {
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Right: Chevron or lock
            if workout.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(workout.isLocked ? Color.clear : Color(.systemBackground))
        .contentShape(Rectangle())
        .opacity(workout.isLocked ? 0.6 : 1.0)
    }
    
    private var statusColor: Color {
        if workout.isCompleted {
            return .green
        } else if workout.isLocked {
            return .gray
        } else {
            return .blue
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

// MARK: - Workout Detail View
struct WorkoutDetailView: View {
    let workout: ProgramWorkoutWithState
    let userProgram: UserProgram?
    let onComplete: () -> Void
    @Binding var isPresentingWorkoutFlow: Bool
    let onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var programService = LocalProgramService.shared
    @State private var isCompleting = false
    @State private var showingCompletionConfirmation = false
    
    init(workout: ProgramWorkoutWithState, userProgram: UserProgram?, onComplete: @escaping () -> Void, isPresentingWorkoutFlow: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self.workout = workout
        self.userProgram = userProgram
        self.onComplete = onComplete
        self._isPresentingWorkoutFlow = isPresentingWorkoutFlow
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Workout header
                    workoutHeader
                    
                    // Instructions
                    if let instructions = workout.workout.instructions {
                        instructionsSection(instructions)
                    }
                    
                    // Details
                    detailsSection
                    
                    // Completion status
                    if workout.isCompleted {
                        completedSection
                    } else if !workout.isLocked {
                        actionSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle(workout.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
    
    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: workoutIcon)
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Spacer()
                
                if workout.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                }
            }
            
            Text(workout.displayTitle)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Day \(workout.workout.dayNumber) • Week \(workout.weekNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func instructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Instructions", systemImage: "list.bullet.clipboard")
                .font(.headline)
            
            Text(instructions)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout Details", systemImage: "info.circle")
                .font(.headline)
            
            if let distance = workout.workout.distanceMiles {
                DetailRow(label: "Distance", value: "\(String(format: "%.1f", distance)) miles")
            }
            
            if let pace = workout.workout.targetPaceMinutes {
                DetailRow(label: "Target Pace", value: "\(Int(pace)) min/mile")
            }
            
            if let weight = userProgram?.currentWeightLbs {
                DetailRow(label: "Ruck Weight", value: "\(Int(weight)) lbs")
            }
            
            DetailRow(label: "Workout Type", value: workout.workout.workoutType.rawValue.capitalized)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var completedSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Workout Completed!")
                .font(.title3)
                .fontWeight(.semibold)
            
            if let completionDate = workout.completionDate {
                Text("Completed on \(completionDate, style: .date)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            if workout.workout.workoutType == .rest {
                Button(action: {
                    showingCompletionConfirmation = true
                }) {
                    HStack {
                        if isCompleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark as Complete")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isCompleting)
            } else {
                Button(action: {
                    startWorkoutTracking()
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Workout")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Text("Tip: After completing, return here to mark as complete and unlock next workout")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var workoutIcon: String {
        switch workout.workout.workoutType {
        case .ruck:
            return "figure.walk"
        case .rest:
            return "bed.double.fill"
        case .crossTraining:
            return "figure.run"
        }
    }
    
    private func startWorkoutTracking() {
        // Get the ruck weight from the program
        let weight = userProgram?.currentWeightLbs ?? 20.0
        
        // Start the workout with the program weight
        workoutManager.startWorkout(weight: weight)
        
        // Dismiss all modal sheets by setting the shared binding to false
        // This is the clean, Apple-recommended way to handle nested modal presentations
        isPresentingWorkoutFlow = false
    }
    
    private func completeWorkout() async {
        guard let programId = programService.getEnrolledProgramId() else { return }
        
        isCompleting = true
        defer { isCompleting = false }
        
        let distance = workout.workout.distanceMiles ?? 0.0
        let weight = userProgram?.currentWeightLbs ?? 20.0
        let duration = Int((distance * (workout.workout.targetPaceMinutes ?? 15.0)))
        
        // This is now synchronous
        programService.completeWorkout(
            programId: programId,
            workoutDay: workout.workout.dayNumber,
            distanceMiles: distance,
            weightLbs: weight,
            durationMinutes: duration
        )
        
        onComplete()
        dismiss()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
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
