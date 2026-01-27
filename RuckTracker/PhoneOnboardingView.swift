import SwiftUI
import CoreLocation

struct PhoneOnboardingView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var programService = LocalProgramService.shared
    @ObservedObject var userSettings = UserSettings.shared
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentStep = 0
    @State private var recommendedProgramID: String = ""
    @State private var recommendedProgramTitle: String = ""
    @State private var baselinePaceInput: String = "16"
    @State private var baselineDistanceInput: String = "4"
    @State private var eventDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var hillAccess: Bool = true
    @State private var stairsAccess: Bool = false
    @State private var injuryNotes: String = ""
    @State private var showingProgressFeedback = false
    @State private var progressFeedbackText = ""
    
    var body: some View {
        ZStack {
            AppColors.backgroundGradient.ignoresSafeArea()
            
            VStack {
                // Progress Bar
                HStack(spacing: 4) {
                    ForEach(0..<8) { index in
                        Capsule()
                            .fill(index <= currentStep ? AppColors.primary : AppColors.accentWarm.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                TabView(selection: $currentStep) {
                    // Step 1: The Welcome (Identity)
                    WelcomeCoachStep(nextAction: { nextStep() })
                        .tag(0)
                    
                    // Step 2: The Goal (Psychology)
                    GoalSelectionStep(selectedGoal: $userSettings.ruckingGoal, nextAction: { nextStepWithFeedback() })
                        .tag(1)
                    
                    // Step 3: Experience (Calibration)
                    ExperienceSelectionStep(selectedExperience: $userSettings.experienceLevel, nextAction: { 
                        calculateRecommendation()
                        nextStepWithFeedback() 
                    })
                    .tag(2)
                    
                    // Step 4: Baseline Metrics
                    BaselineMetricsStep(
                        baselinePace: $baselinePaceInput,
                        baselineDistance: $baselineDistanceInput,
                        nextAction: { applyBaselines(); nextStepWithFeedback() }
                    )
                    .tag(3)
                    
                    // Step 5: Terrain & Event (Context)
                    TerrainEventStep(
                        eventDate: $eventDate,
                        hasHills: $hillAccess,
                        hasStairs: $stairsAccess,
                        injuryNotes: $injuryNotes,
                        nextAction: { applyTerrainAndInjuries(); nextStepWithFeedback() },
                        backAction: previousStep
                    )
                    .tag(4)
                    
                    // Step 6: Preferred Training Days (Schedule)
                    TrainingDaysSelectionStep(selectedDays: $userSettings.preferredTrainingDays, nextAction: { nextStepWithFeedback() })
                        .tag(5)
                    
                    // Step 7: The Reveal (The Product)
                    ProgramRecommendationStep(
                        goal: userSettings.ruckingGoal,
                        programTitle: recommendedProgramTitle,
                        nextAction: { nextStepWithFeedback() }
                    )
                    .tag(6)
                    
                    // Step 8: The Buy-in (Permissions)
                    PermissionsStep(
                        healthManager: healthManager, 
                        workoutManager: workoutManager, 
                        onComplete: { hasCompletedOnboarding = true }
                    )
                    .tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            // Progress feedback overlay
            .overlay(
                Group {
                    if showingProgressFeedback {
                        VStack {
                            Spacer()
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accentGreen)
                                    .font(.title3)
                                
                                Text(progressFeedbackText)
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.overlayBlack)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.primary, lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 30)
                            .padding(.bottom, 100)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            )
        }
        .onAppear {
            baselinePaceInput = String(format: "%.0f", userSettings.baselinePaceMinutesPerMile)
            baselineDistanceInput = String(format: "%.0f", userSettings.baselineLongestDistanceMiles)
            eventDate = userSettings.targetEventDate ?? eventDate
            hillAccess = userSettings.hasHillAccess
            stairsAccess = userSettings.hasStairsAccess
            injuryNotes = userSettings.injuryFlags.joined(separator: ", ")
        }
    }
    
    private func nextStep() {
        currentStep += 1
    }
    
    private func previousStep() {
        currentStep = max(0, currentStep - 1)
    }
    
    private func nextStepWithFeedback() {
        // Show feedback based on which step was just completed
        let feedbackMessages = [
            "✓ Goal set", // After step 1 (goal selection)
            "✓ Experience calibrated", // After step 2 (experience)
            "✓ Baselines captured", // After step 3 (baseline metrics)
            "✓ Environment mapped", // After step 4 (terrain)
            "✓ Schedule locked", // After step 5 (training days)
            "✓ Program built", // After step 6 (program reveal)
            "" // No feedback after final step
        ]
        
        // Get feedback for current step (if available)
        if currentStep < feedbackMessages.count {
            progressFeedbackText = feedbackMessages[currentStep]
            
            if !progressFeedbackText.isEmpty {
                // Show the feedback
                withAnimation(.easeIn(duration: 0.2)) {
                    showingProgressFeedback = true
                }
                
                // Hide it and move to next step
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingProgressFeedback = false
                    }
                    
                    // Move to next step after feedback fades
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        currentStep += 1
                    }
                }
            } else {
                // No feedback, just move to next step
                currentStep += 1
            }
        } else {
            // Beyond feedback array, just move forward
            currentStep += 1
        }
    }
    
    private func calculateRecommendation() {
        let generated = MarchPlanGenerator.generatePlan(for: userSettings)
        programService.upsertMarchProgram(generated)
        
        recommendedProgramID = generated.program.id.uuidString
        recommendedProgramTitle = generated.program.title
        userSettings.activeProgramID = recommendedProgramID
    }
    
    private func applyBaselines() {
        if let pace = Double(baselinePaceInput) {
            userSettings.baselinePaceMinutesPerMile = pace
        }
        if let distance = Double(baselineDistanceInput) {
            userSettings.baselineLongestDistanceMiles = distance
        }
    }
    
    private func applyTerrainAndInjuries() {
        userSettings.targetEventDate = eventDate
        userSettings.hasHillAccess = hillAccess
        userSettings.hasStairsAccess = stairsAccess
        userSettings.injuryFlags = injuryNotes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

// MARK: - Subviews

struct WelcomeCoachStep: View {
    var nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App branding
            Text("MARCH")
                .font(.system(size: 60, weight: .black))
                .foregroundColor(AppColors.primary)
            
            Text("POCKET COACH")
                .font(.headline)
                .tracking(4)
                .foregroundColor(AppColors.textPrimary)
            
            // Main value prop
            Text("Training for longevity, hunting, or a GORUCK event?\n\nWe build the plan. You do the work.")
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 30)
                .padding(.top, 10)
            
            Spacer()
                .frame(height: 40)
            
            // NEW: Expectation setting box
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.caption)
                    Text("2 minutes to build your plan")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Text("8 quick questions")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
            .padding()
            .background(AppColors.overlayWhiteLight)
            .cornerRadius(12)
            .padding(.horizontal, 30)
            
            Spacer()
            
            // CTA button
            Button(action: nextAction) {
                Text("Build My Plan")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primaryGradient)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
    }
}

struct GoalSelectionStep: View {
    @Binding var selectedGoal: RuckingGoal
    var nextAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What are we training for?")
                .font(.title).bold().foregroundColor(AppColors.textPrimary)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(RuckingGoal.allCases, id: \.self) { goal in
                        Button(action: {
                            selectedGoal = goal
                            nextAction()
                        }) {
                            HStack {
                                Image(systemName: goal.icon)
                                    .frame(width: 30)
                                Text(goal.rawValue)
                                    .font(.headline)
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppColors.overlayWhite)
                            .cornerRadius(12)
                    .foregroundColor(selectedGoal == goal ? AppColors.primary : AppColors.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedGoal == goal ? AppColors.primary : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ExperienceSelectionStep: View {
    @Binding var selectedExperience: ExperienceLevel
    var nextAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What is your baseline?")
                .font(.title).bold().foregroundColor(AppColors.textPrimary)
            
            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                Button(action: {
                    selectedExperience = level
                    nextAction()
                }) {
                    HStack {
                        Text(level.rawValue)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.overlayWhite)
                    .cornerRadius(12)
                    .foregroundColor(AppColors.textPrimary)
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct TrainingDaysSelectionStep: View {
    @Binding var selectedDays: [Int]
    var nextAction: () -> Void
    
    private let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon-Sun display order
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("When do you want to train?")
                .font(.title).bold().foregroundColor(AppColors.textPrimary)
            
            Text("Pick the days you can consistently ruck. We'll schedule workouts around your life.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(orderedWeekdays, id: \.self) { day in
                    Button(action: { toggle(day) }) {
                        VStack(spacing: 8) {
                            Text(shortLabel(for: day))
                                .font(.headline)
                            Text(longLabel(for: day))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isSelected(day) ? AppColors.primary : AppColors.textPrimary.opacity(0.1))
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected(day) ? AppColors.primary : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Lock Schedule")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedDays.isEmpty ? AppColors.accentWarm.opacity(0.3) : AppColors.primary)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(12)
            }
            .disabled(selectedDays.isEmpty)
        }
        .padding()
    }
    
    private func toggle(_ day: Int) {
        if let index = selectedDays.firstIndex(of: day) {
            selectedDays.remove(at: index)
        } else {
            selectedDays.append(day)
        }
    }
    
    private func isSelected(_ day: Int) -> Bool {
        selectedDays.contains(day)
    }
    
    private func shortLabel(for day: Int) -> String {
        let index = (day - 1 + 7) % 7
        return calendar.shortWeekdaySymbols[index]
    }
    
    private func longLabel(for day: Int) -> String {
        let index = (day - 1 + 7) % 7
        return calendar.weekdaySymbols[index]
    }
}

struct BaselineMetricsStep: View {
    @Binding var baselinePace: String
    @Binding var baselineDistance: String
    var nextAction: () -> Void
    
    // These will be the user's selections (we'll convert to strings later)
    @State private var selectedPaceLevel: PaceLevel = .moderate
    @State private var selectedDistanceLevel: DistanceLevel = .moderate
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calibrate your plan")
                        .font(.title).bold().foregroundColor(AppColors.textPrimary)
                    
                    Text("Tell us your current comfortable pace with 20 lbs so we scale load safely.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // PACE SELECTION (multiple choice)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comfortable pace with 20 lbs:")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    ForEach(PaceLevel.allCases, id: \.self) { level in
                        Button(action: {
                            selectedPaceLevel = level
                        }) {
                            HStack {
                                // Icon based on pace
                                Text(level.emoji)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.label)
                                        .font(.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text(level.description)
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                if selectedPaceLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                            .padding()
                            .background(AppColors.overlayWhite)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPaceLevel == level ? AppColors.primary : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // DISTANCE SELECTION (multiple choice)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Longest recent ruck:")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    ForEach(DistanceLevel.allCases, id: \.self) { level in
                        Button(action: {
                            selectedDistanceLevel = level
                        }) {
                            HStack {
                                // Icon
                                Image(systemName: level.icon)
                                    .font(.title3)
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.label)
                                        .font(.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text(level.description)
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                if selectedDistanceLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                            .padding()
                            .background(AppColors.overlayWhite)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedDistanceLevel == level ? AppColors.primary : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Reassurance text
                Text("Don't worry - we'll adjust after your first workout")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    .italic()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                
                // Continue button
                Button(action: {
                    // Convert selections to strings before continuing
                    baselinePace = String(selectedPaceLevel.paceValue)
                    baselineDistance = String(selectedDistanceLevel.distanceValue)
                    nextAction()
                }) {
                    Text("Continue")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primaryGradient)
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

// MARK: - Supporting Enums

// This defines the pace options users can choose from
enum PaceLevel: CaseIterable {
    case slow
    case moderate
    case fast
    case veryFast
    
    var emoji: String {
        switch self {
        case .slow: return "🐌"
        case .moderate: return "🚶"
        case .fast: return "⚡"
        case .veryFast: return "🏃"
        }
    }
    
    var label: String {
        switch self {
        case .slow: return "Slow"
        case .moderate: return "Moderate"
        case .fast: return "Fast"
        case .veryFast: return "Very Fast"
        }
    }
    
    var description: String {
        switch self {
        case .slow: return "20+ min/mile - Taking it easy"
        case .moderate: return "16-20 min/mile - Steady pace"
        case .fast: return "12-16 min/mile - Pushing myself"
        case .veryFast: return "<12 min/mile - Near running"
        }
    }
    
    var paceValue: Int {
        switch self {
        case .slow: return 22
        case .moderate: return 18
        case .fast: return 14
        case .veryFast: return 11
        }
    }
}

// This defines the distance options users can choose from
enum DistanceLevel: CaseIterable {
    case beginner
    case moderate
    case advanced
    case elite
    
    var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .moderate: return "figure.walk.motion"
        case .advanced: return "figure.hiking"
        case .elite: return "figure.run"
        }
    }
    
    var label: String {
        switch self {
        case .beginner: return "1-2 miles"
        case .moderate: return "3-5 miles"
        case .advanced: return "6-10 miles"
        case .elite: return "10+ miles"
        }
    }
    
    var description: String {
        switch self {
        case .beginner: return "Just getting started"
        case .moderate: return "Building endurance"
        case .advanced: return "Strong base fitness"
        case .elite: return "Experienced rucker"
        }
    }
    
    var distanceValue: Int {
        switch self {
        case .beginner: return 2
        case .moderate: return 4
        case .advanced: return 8
        case .elite: return 12
        }
    }
}

struct TerrainEventStep: View {
    @Binding var eventDate: Date
    @Binding var hasHills: Bool
    @Binding var hasStairs: Bool
    @Binding var injuryNotes: String
    var nextAction: () -> Void
    var backAction: () -> Void
    
    @State private var hasEvent: Bool = false // NEW: Track if user has an event
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training environment")
                        .font(.title).bold().foregroundColor(AppColors.textPrimary)
                    
                    Text("We'll adapt your program to match your terrain and timeline.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // TERRAIN SELECTION (checkbox style - all valid)
                VStack(alignment: .leading, spacing: 12) {
                    Text("What terrain do you have access to?")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Select all that apply")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    
                    // Hills checkbox
                    Button(action: { hasHills.toggle() }) {
                        HStack {
                            Image(systemName: hasHills ? "checkmark.square.fill" : "square")
                                .foregroundColor(hasHills ? AppColors.primary : AppColors.textSecondary)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hills nearby")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Adds elevation workouts")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(AppColors.overlayWhite)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Stairs checkbox
                    Button(action: { hasStairs.toggle() }) {
                        HStack {
                            Image(systemName: hasStairs ? "checkmark.square.fill" : "square")
                                .foregroundColor(hasStairs ? AppColors.primary : AppColors.textSecondary)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stairs or buildings")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Enables stair workouts")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(AppColors.overlayWhite)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Flat terrain (always available, just informational)
                    HStack {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundColor(AppColors.accentGreen)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flat terrain")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Core rucking workouts")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(AppColors.overlayWhiteLight)
                    .cornerRadius(12)
                }
                
                Divider()
                    .background(AppColors.overlayWhiteMedium)
                    .padding(.vertical, 8)
                
                // EVENT SELECTION (now optional!)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Training for something specific?")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    // Yes/No toggle
                    HStack(spacing: 12) {
                        Button(action: { hasEvent = false }) {
                            HStack {
                                Image(systemName: !hasEvent ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(AppColors.primary)
                                Text("No - Just getting stronger")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(!hasEvent ? AppColors.primary.opacity(0.2) : AppColors.overlayWhite)
                            .cornerRadius(12)
                            .foregroundColor(AppColors.textPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { hasEvent = true }) {
                            HStack {
                                Image(systemName: hasEvent ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(AppColors.primary)
                                Text("Yes - I have an event")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasEvent ? AppColors.primary.opacity(0.2) : AppColors.overlayWhite)
                            .cornerRadius(12)
                            .foregroundColor(AppColors.textPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Event date picker (only show if they have an event)
                    if hasEvent {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event date:")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            DatePicker("", selection: $eventDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding()
                                .background(AppColors.overlayWhite)
                                .cornerRadius(12)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                // REMOVED injury notes - too personal, move to settings
                
                // Continue button
                Button(action: nextAction) {
                    Text("Continue")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primaryGradient)
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

struct ProgramRecommendationStep: View {
    let goal: RuckingGoal
    let programTitle: String
    var nextAction: () -> Void
    
    @State private var showContent = false // For animation
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)
                
                // Build-up text
                if showContent {
                    VStack(spacing: 8) {
                        Text("Your Personalized Program")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(2)
                        
                        // Program title - BIG and bold
                        Text(programTitle)
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(AppColors.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)
                }
                
                if showContent {
                    // Program details card
                    VStack(spacing: 16) {
                        HStack(spacing: 30) {
                            // Duration
                            VStack(spacing: 4) {
                                Text(programDuration)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("weeks")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Divider()
                                .frame(height: 40)
                                .background(AppColors.overlayWhiteStrong)
                            
                            // Frequency
                            VStack(spacing: 4) {
                                Text(programFrequency)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("days/week")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppColors.overlayWhiteLight)
                        .cornerRadius(16)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showContent)
                }
                
                if showContent {
                    // Week 1 Preview
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Week 1 Preview")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        // Sample workouts based on goal
                        VStack(spacing: 12) {
                            WorkoutPreviewRow(
                                day: "Monday",
                                workout: getWeek1Workout(day: 1)
                            )
                            WorkoutPreviewRow(
                                day: "Wednesday",
                                workout: getWeek1Workout(day: 2)
                            )
                            WorkoutPreviewRow(
                                day: "Friday",
                                workout: getWeek1Workout(day: 3)
                            )
                            WorkoutPreviewRow(
                                day: "Saturday",
                                workout: getWeek1Workout(day: 4)
                            )
                        }
                    }
                    .padding()
                    .background(AppColors.overlayWhiteLight)
                    .cornerRadius(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: showContent)
                }
                
                if showContent {
                    // Value prop reminder
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.accentGreen)
                            Text("Adapts to YOUR schedule")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.accentGreen)
                            Text("Matches YOUR terrain")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.accentGreen)
                            Text("Scales to YOUR goals")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: showContent)
                }
                
                Spacer()
                
                if showContent {
                    // CTA button
                    Button(action: nextAction) {
                        Text("Start Training")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primaryGradient)
                            .foregroundColor(AppColors.textPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: showContent)
                }
            }
        }
        .onAppear {
            // Trigger the reveal animation after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showContent = true
            }
        }
    }
    
    // Helper computed properties
    private var programDuration: String {
        if goal == .military || goal == .hiking {
            return "12"
        } else if goal == .goruckTough {
            return "8"
        } else {
            return "6"
        }
    }
    
    private var programFrequency: String {
        if goal == .military {
            return "5"
        } else {
            return "4"
        }
    }
    
    // Generate sample workouts based on goal
    private func getWeek1Workout(day: Int) -> String {
        switch goal {
        case .goruckBasic, .goruckTough:
            switch day {
            case 1: return "3 miles @ 20 lbs • Zone 2"
            case 2: return "2 miles @ 30 lbs • Power"
            case 3: return "4 miles @ 20 lbs • Endurance"
            case 4: return "Stairs + 20 lbs • 30 min"
            default: return "Rest"
            }
        case .military:
            switch day {
            case 1: return "4 miles @ 30 lbs • Zone 2"
            case 2: return "3 miles @ 40 lbs • Power"
            case 3: return "6 miles @ 30 lbs • Long Ruck"
            case 4: return "Hills + 30 lbs • 45 min"
            default: return "Rest"
            }
        case .hiking, .longevity, .weightLoss:
            switch day {
            case 1: return "2 miles @ 20 lbs • Easy"
            case 2: return "3 miles @ 20 lbs • Steady"
            case 3: return "4 miles @ 20 lbs • Build"
            case 4: return "Varied terrain • 30 min"
            default: return "Rest"
            }
        }
    }
}

// MARK: - Supporting Views

struct WorkoutPreviewRow: View {
    let day: String
    let workout: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Day indicator
            Circle()
                .fill(AppColors.primary.opacity(0.3))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
                    .textCase(.uppercase)
                
                Text(workout)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
    }
}

// PermissionsStep can remain similar to previous iteration or just generic permissions
struct PermissionsStep: View {
    @ObservedObject var healthManager: HealthManager
    @ObservedObject var workoutManager: WorkoutManager
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Final Setup")
                .font(.title).bold().foregroundColor(AppColors.textPrimary)
            Text("To be your coach, we need to see your data.")
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            // Simplified for brevity
            Button(action: { healthManager.requestAuthorization() }) {
                Text("Connect HealthKit")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(healthManager.isAuthorized ? AppColors.accentGreen : AppColors.textPrimary.opacity(0.1))
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(12)
            }
            
            Button(action: { workoutManager.requestLocationPermission() }) {
                Text("Enable GPS")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primaryGradient)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(12)
            }
            
            Spacer()
            
            Button(action: onComplete) {
                Text("Let's Ruck")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primaryGradient)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
}
