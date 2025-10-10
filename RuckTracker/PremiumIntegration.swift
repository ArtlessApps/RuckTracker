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
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var premiumManager = PremiumManager.shared
    @State private var showingSettings = false
    
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
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var programService = LocalProgramService.shared
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
            ProgramDetailView(
                program: program,
                isPresentingWorkoutFlow: Binding.constant(false),
                onDismiss: {
                    selectedProgram = nil
                }
            )
            .environmentObject(programService)
        }
        .onAppear {
            // Load programs when view appears
            programService.loadPrograms()
            programService.loadEnrollmentStatus()
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
            ScrollView {
                VStack(spacing: 16) {
                    // ENROLLED PROGRAMS SECTION (NEW)
                    if !enrolledPrograms.isEmpty {
                        enrolledProgramsSection
                    }
                    
                    // AVAILABLE PROGRAMS SECTION
                    availableProgramsSection
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var enrolledPrograms: [(UserProgram, Program)] {
        programService.userPrograms
            .filter { $0.isActive }
            .compactMap { userProgram in
                if let program = programService.programs.first(where: { $0.id == userProgram.programId }) {
                    return (userProgram, program)
                }
                return nil
            }
            .sorted { $0.0.startDate > $1.0.startDate } // Most recent first
    }
    
    private var availablePrograms: [Program] {
        let enrolledIds = Set(programService.userPrograms.map { $0.programId })
        return programService.programs
            .filter { !enrolledIds.contains($0.id) }
            .sorted { $0.isFeatured && !$1.isFeatured } // Featured first
    }
    
    // MARK: - Enrolled Section
    
    private var enrolledProgramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            ForEach(enrolledPrograms, id: \.0.id) { userProgram, program in
                EnhancedProgramCard(
                    program: program,
                    isEnrolled: true,
                    userProgram: userProgram,
                    fullWidth: true
                ) {
                    // Navigate to program detail
                    selectedProgram = program
                }
            }
            
            Divider()
                .padding(.vertical, 8)
        }
    }
    
    // MARK: - Available Section
    
    private var availableProgramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Programs")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(availablePrograms) { program in
                    EnhancedProgramCard(
                        program: program,
                        isEnrolled: false,
                        userProgram: nil,
                        fullWidth: false
                    ) {
                        selectedProgram = program
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // MARK: - Progress Calculation
    private func getProgress(programId: UUID) -> (completed: Int, total: Int, percentage: Int) {
        guard let program = programService.programs.first(where: { $0.id == programId }) else {
            return (completed: 0, total: 0, percentage: 0)
        }
        
        // Calculate total workouts for the program
        let totalWorkouts = getTotalWorkouts(for: program)
        
        // Get user program to calculate completed workouts
        // Check if enrolled in program
        guard programService.isEnrolledIn(programId: programId) else {
            return (completed: 0, total: 0, percentage: 0)
        }
        
        // Create a mock UserProgram for calculation
        let userProgram = UserProgram(programId: programId, targetWeight: 0.0)
        let completedWorkouts = getCompletedWorkouts(for: userProgram)
        
        // Calculate percentage
        let percentage = totalWorkouts > 0 ? Int((Double(completedWorkouts) / Double(totalWorkouts)) * 100) : 0
        
        return (completed: completedWorkouts, total: totalWorkouts, percentage: percentage)
    }
    
    private func getNextWorkout(programId: UUID) -> String? {
        guard let program = programService.programs.first(where: { $0.id == programId }) else {
            return nil
        }
        
        // In a real implementation, this would:
        // 1. Fetch all workouts for the program
        // 2. Find the first incomplete workout
        // 3. Return the workout name/description
        // For now, returning a mock next workout name
        return getNextWorkoutName(for: program)
    }
    
    // MARK: - Real Implementation Helpers (for future use)
    private func getProgressFromWorkouts(programId: UUID) -> (completed: Int, total: Int, percentage: Int) {
        // This would be the real implementation when workout data is available
        /*
        guard let program = programService.programs.first(where: { $0.id == programId }),
              let workouts = program.workouts else {
            return (completed: 0, total: 0, percentage: 0)
        }
        
        let completed = workouts.filter { $0.completed }.count
        let total = workouts.count
        let percentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
        
        return (completed: completed, total: total, percentage: percentage)
        */
        
        // Fallback to mock implementation
        return getProgress(programId: programId)
    }
    
    private func getNextWorkoutFromWorkouts(programId: UUID) -> String? {
        // This would be the real implementation when workout data is available
        /*
        guard let program = programService.programs.first(where: { $0.id == programId }),
              let workouts = program.workouts else {
            return nil
        }
        
        // Find the first incomplete workout
        let nextWorkout = workouts.first { !$0.completed } ?? workouts.first
        return nextWorkout?.name
        */
        
        // Fallback to mock implementation
        return getNextWorkout(programId: programId)
    }
    
    // MARK: - Legacy Helper Functions (Updated to use new progress calculation)
    private func getNextWorkoutName(for program: Program) -> String? {
        // Mock implementation - in real app, this would fetch from program workouts
        return "3 Mile Ruck @ 25lbs"
    }
    
    private func getCompletedWorkouts(for userProgram: UserProgram?) -> Int {
        guard let userProgram = userProgram else { return 0 }
        
        // Use the new progress calculation
        let progress = getProgress(programId: userProgram.programId)
        return progress.completed
    }
    
    private func getTotalWorkouts(for program: Program) -> Int {
        // Mock implementation - in real app, this would count total program workouts
        return program.durationWeeks * 5 // Assume 5 workouts per week
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

// MARK: - Enrolled Program Card
struct EnrolledProgramCard: View {
    let program: Program
    let progress: ProgramProgress
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let description = program.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                // Progress information
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Week \(progress.currentWeek)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("\(progress.completed)/\(progress.total) workouts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: progress.completionPercentage / 100.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(y: 1.5)
                }
            }
            .padding()
            .background(Color.green.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enrolled Program Card (Specialized Variant)
struct EnrolledProgramCardDetailed: View {
    let program: Program
    let userProgram: UserProgram
    let nextWorkout: String?
    let completedWorkouts: Int
    let totalWorkouts: Int
    let onNavigateToNextWorkout: () -> Void
    let onLaunchWorkoutTracker: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row: Target icon + program name + ACTIVE badge
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text(program.title.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // ACTIVE badge - exact design tokens
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Text("ACTIVE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 16/255, green: 185/255, blue: 129/255))  // #10B981
                .cornerRadius(12)
            }
            
            // Action row: Continue Program + arrow (with separate handlers)
            HStack {
                Button(action: onNavigateToNextWorkout) {
                    Text("Continue Program")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onLaunchWorkoutTracker) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Next workout information
            if let nextWorkout = nextWorkout {
                HStack {
                    Text("Next:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(nextWorkout)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            // Workout details: Week • Day • Distance • Weight
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Week \(userProgram.currentWeek)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Day \(calculateCurrentDay())")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("3.0 mi")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "backpack.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(Int(userProgram.currentWeightLbs)) lbs")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            // Progress bar with text
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Progress:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(completedWorkouts)/\(totalWorkouts) (\(Int(progressPercentage))%)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Progress bar with exact design tokens
                ProgressView(value: progressPercentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 59/255, green: 130/255, blue: 246/255)))  // #3B82F6
                    .frame(height: 6)  // Exact height from design tokens
                    .background(Color(red: 229/255, green: 231/255, blue: 235/255))  // #E5E7EB
                    .cornerRadius(3)
            }
        }
        .padding(16)  // Exact padding from design tokens
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 59/255, green: 130/255, blue: 246/255, opacity: 0.05))  // rgba(59, 130, 246, 0.05)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 59/255, green: 130/255, blue: 246/255), lineWidth: 2)  // #3B82F6
                )
        )
        .onTapGesture {
            // Main card tap navigates to next workout detail
            onNavigateToNextWorkout()
        }
    }
    
    private var progressPercentage: Double {
        guard totalWorkouts > 0 else { return 0 }
        return (Double(completedWorkouts) / Double(totalWorkouts)) * 100
    }
    
    private func calculateCurrentDay() -> Int {
        // Calculate current day based on week and typical 7-day structure
        return ((userProgram.currentWeek - 1) * 7) + 1
    }
}

// MARK: - Flexible Grid Container
struct FlexGrid: View {
    let programs: [Program]
    @Binding var selectedProgram: Program?
    @ObservedObject private var programService = LocalProgramService.shared
    
    init(programs: [Program], selectedProgram: Binding<Program?>) {
        self.programs = programs
        self._selectedProgram = selectedProgram
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Separate enrolled and available programs
            let enrolledPrograms = programs.filter { program in
                programService.isEnrolledIn(programId: program.id)
            }
            let availablePrograms = programs.filter { program in
                !programService.isEnrolledIn(programId: program.id)
            }
            
            // Enrolled programs section (full width)
            if !enrolledPrograms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Programs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    LazyVStack(spacing: 16) {  // 16px marginBottom from design tokens
                        ForEach(enrolledPrograms) { program in
                            if programService.isEnrolledIn(programId: program.id) {
                                // Create a mock UserProgram for the detailed card
                                let mockUserProgram = UserProgram(
                                    programId: program.id,
                                    targetWeight: 0.0
                                )
                                
                                EnrolledProgramCardDetailed(
                                    program: program,
                                    userProgram: mockUserProgram,
                                    nextWorkout: getNextWorkoutName(for: program),
                                    completedWorkouts: getCompletedWorkouts(for: mockUserProgram),
                                    totalWorkouts: getTotalWorkouts(for: program),
                                    onNavigateToNextWorkout: {
                                        selectedProgram = program
                                    },
                                    onLaunchWorkoutTracker: {
                                        print("Launch workout tracker for program: \(program.title)")
                                    }
                                )
                            }
                        }
                    }
                }
            }
            
            // Available programs section (grid layout)
            if !availablePrograms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Programs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    // Flexible grid that handles mixed widths
                    FlexibleGrid(programs: availablePrograms, selectedProgram: $selectedProgram)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func getNextWorkoutName(for program: Program) -> String? {
        return "3 Mile Ruck @ 25lbs"
    }
    
    private func getCompletedWorkouts(for userProgram: UserProgram) -> Int {
        return Int(userProgram.completionPercentage / 10)
    }
    
    private func getTotalWorkouts(for program: Program) -> Int {
        return program.durationWeeks * 5
    }
}

// MARK: - Flexible Grid for Available Programs
struct FlexibleGrid: View {
    let programs: [Program]
    @Binding var selectedProgram: Program?
    
    init(programs: [Program], selectedProgram: Binding<Program?>) {
        self.programs = programs
        self._selectedProgram = selectedProgram
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 16) {
            ForEach(programs) { program in
                EnhancedProgramCard(
                    program: program,
                    isEnrolled: false,
                    userProgram: nil,
                    fullWidth: false
                ) {
                    selectedProgram = program
                }
            }
        }
    }
}

// MARK: - Enhanced Program Card with Enrollment Status
struct EnhancedProgramCard: View {
    let program: Program
    let isEnrolled: Bool
    let userProgram: UserProgram?
    let fullWidth: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and enrollment status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        if let description = program.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Enrollment status indicator
                    if isEnrolled {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Active")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Progress information for enrolled programs
                if isEnrolled, let userProgram = userProgram {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Week \(userProgram.currentWeek)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text("\(Int(userProgram.currentWeightLbs)) lbs")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        
                        // Progress bar
                        ProgressView(value: userProgram.completionPercentage / 100.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .scaleEffect(y: 1.5)
                    }
                    .padding(.top, 4)
                }
                
                // Bottom section with difficulty and weeks
                HStack {
                    Label(program.difficulty.rawValue.capitalized, systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    if program.durationWeeks > 0 {
                        Text("\(program.durationWeeks)w")
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
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isEnrolled {
            return Color.green.opacity(0.08)
        } else {
            return Color.gray.opacity(0.08)
        }
    }
    
    private var borderColor: Color {
        if isEnrolled {
            return Color.green.opacity(0.3)
        } else {
            return Color.blue.opacity(0.2)
        }
    }
    
    private var borderWidth: CGFloat {
        return isEnrolled ? 2 : 1
    }
}

// MARK: - Functional Program Card (Legacy)
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
                        showingEnrollment = true
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
    
    private func enrollInProgram(startingWeight: Double) {
        // Remove the async/await - now synchronous
        programService.enrollInProgram(program, startingWeight: startingWeight)
        
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
        // Check if enrolled
        let enrolled = programService.isEnrolledIn(programId: program.id)
        
        await MainActor.run {
            self.isEnrolled = enrolled
            if enrolled {
                // Create a mock UserProgram when enrolled
                self.userProgram = UserProgram(programId: program.id, targetWeight: 0.0)
            }
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
    let program: Program
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
        }
        .task {
            await loadWorkouts()
        }
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
            let completedWorkoutDays = WorkoutDataManager.shared.workouts
                .filter { $0.programId == program.id.uuidString }
                .compactMap { Int($0.programWorkoutDay) }
            
            // Map workouts to state
            var lastCompletedIndex = -1
            
            workouts = programWorkouts.enumerated().map { index, workout in
                let isCompleted = completedWorkoutDays.contains(workout.dayNumber)
                
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
                
                return ProgramWorkoutWithState(
                    workout: workout,
                    weekNumber: (workout.dayNumber - 1) / 7 + 1,
                    isCompleted: isCompleted,
                    isLocked: isLocked,
                    completionDate: nil
                )
            }
            
            print("✅ Loaded \(workouts.count) workouts, \(completedWorkoutDays.count) completed")
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
