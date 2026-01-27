import SwiftUI
import Foundation
import Combine

// MARK: - Main Phone View Coordinator
struct ImprovedPhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @ObservedObject private var userSettings = UserSettings.shared
    @ObservedObject private var programService = LocalProgramService.shared
    
    @State private var upcomingWorkouts: [ScheduledWorkout] = []
    @State private var coachPlanTitle: String?
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
    @State private var showingActiveWorkout = false
    @State private var selectedProgramWorkout: ProgramWorkoutWithState?
    @State private var selectedUserProgram: UserProgram?
    @State private var selectedProgramId: UUID?
    @State private var pendingShareCode: String?
    @State private var selectedSessionType: SessionType?
    @State private var showingSessionConfig = false
    
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
    
    // MARK: - Quick Session Types
    enum SessionType: CaseIterable {
        case justRuck
        case recovery
        case pacePusher
        case vertical
        case benchmark
        
        var title: String {
            switch self {
            case .justRuck: return "Just Ruck"
            case .recovery: return "Recovery"
            case .pacePusher: return "Pace Pusher"
            case .vertical: return "Vertical"
            case .benchmark: return "Benchmark"
            }
        }
        
        var subtitle: String {
            switch self {
            case .justRuck: return "Open-ended. Stop when you're done."
            case .recovery: return "Zone 2 focus. Choose duration."
            case .pacePusher: return "Intervals for speed."
            case .vertical: return "Hill repeats. Choose elevation."
            case .benchmark: return "Standards for distance/time."
            }
        }
        
        var icon: String {
            switch self {
            case .justRuck: return "figure.walk"
            case .recovery: return "bolt.heart"
            case .pacePusher: return "hare.fill"
            case .vertical: return "mountain.2.fill"
            case .benchmark: return "trophy.fill"
            }
        }
        
        var accent: Color {
            switch self {
            case .justRuck: return AppColors.primary
            case .recovery: return AppColors.accentGreenLight
            case .pacePusher: return AppColors.accentGreenDeep
            case .vertical: return AppColors.accentWarm
            case .benchmark: return AppColors.accentGreen
            }
        }
        
        var contextLabel: String {
            switch self {
            case .justRuck: return "Just Ruck"
            case .recovery: return "Recovery Ruck"
            case .pacePusher: return "Pace Pusher Ruck"
            case .vertical: return "Vertical Grind Ruck"
            case .benchmark: return "Standard Test Ruck"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    mainContentView
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
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
                AllWorkoutsView(deepLinkShareCode: pendingShareCode)
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
        .sheet(isPresented: $showingActiveWorkout) {
            ActiveWorkoutFullScreenView()
                .environmentObject(workoutManager)
        }
        .sheet(isPresented: $showingSessionConfig) {
            SessionConfiguratorSheet(
                sessionType: $selectedSessionType,
                onStart: { type, config in
                    startQuickSession(type: type, config: config)
                },
                onCancel: { showingSessionConfig = false }
            )
        }
        .sheet(item: $selectedProgramWorkout, onDismiss: {
            selectedProgramWorkout = nil
        }) { workout in
            WorkoutDetailView(
                workout: workout,
                programId: selectedProgramId,
                userProgram: selectedUserProgram,
                onComplete: {
                    refreshCoachPlan()
                },
                isPresentingWorkoutFlow: $isPresentingWorkoutFlow,
                onDismiss: {
                    selectedProgramWorkout = nil
                }
            )
            .environmentObject(workoutManager)
        }
        .onChange(of: workoutManager.isActive) { oldValue, newValue in
            if newValue && !oldValue {
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingActiveWorkout = true
                }
            }
        }
        .onAppear {
            refreshCoachPlan()
        }
        .onChange(of: userSettings.activeProgramID) { _, _ in
            refreshCoachPlan()
        }
        .onChange(of: userSettings.preferredTrainingDays) { _, _ in
            refreshCoachPlan()
        }
        .onReceive(programService.$programs) { _ in
            refreshCoachPlan()
        }
        .onReceive(programService.$programProgress) { _ in
            refreshCoachPlan()
        }
        .onReceive(deepLinkManager.$pendingDestination.compactMap { $0 }) { destination in
            switch destination {
            case .workoutShare(let code):
                pendingShareCode = code
                activeSheet = .workoutHistory
            case .workoutHistory:
                activeSheet = .workoutHistory
            }
            
            DispatchQueue.main.async {
                deepLinkManager.pendingDestination = nil
            }
        }
    }
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                sessionGrid
                trainingProgramsSection
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 20)
        }
        .background(Color.clear)
    }
    
    // MARK: - Coach + Quick Sessions
    
    private var heroCard: some View {
        Group {
            if let planned = todaysPlannedWorkout {
                Button {
                    startPlannedWorkout(planned)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(programEyebrow)
                            .font(.caption)
                            .fontWeight(.semibold)
                    .foregroundColor(AppColors.textSecondary)
                        Text(planned.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Week \(planned.weekNumber), Day \(planned.dayNumber ?? 1)")
                            .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                        HStack(spacing: 12) {
                            Label(durationLabel(for: planned), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                            Label(intensityLabel(for: planned), systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: AppColors.shadowBlack, radius: 10, x: 0, y: 5)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    activeSheet = .trainingPrograms
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PERSONALIZED PLAN")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Create My Plan")
                            .font(.title2).fontWeight(.bold)
                        Text("We’ll build your schedule from MARCH sessions.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: AppColors.shadowBlack, radius: 10, x: 0, y: 5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var sessionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Ruck")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SessionType.allCases, id: \.self) { type in
                    Button {
                        selectedSessionType = type
                        showingSessionConfig = true
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(type.accent.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: type.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(type.accent)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.title)
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(type.subtitle)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColors.surfaceAlt.opacity(0.6),
                                            AppColors.surfaceAlt.opacity(0.3)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    AppColors.textPrimary.opacity(0.2),
                                                    .clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var trainingProgramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Programs")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(programCardData) { card in
                    Button {
                        if premiumManager.isPremiumUser {
                            activeSheet = .trainingPrograms
                        } else {
                            premiumManager.showPaywall(context: .programAccess)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: card.icon)
                                .font(.title2)
                                .foregroundColor(card.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(card.title)
                                        .font(.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                Text(card.subtitle)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: AppColors.shadowBlack, radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var programCardData: [ProgramCard] {
        [
            ProgramCard(title: "Beginner Ruck", subtitle: "4-week habit build", icon: "leaf.fill", accent: AppColors.accentTealLight),
            ProgramCard(title: "Pro Pathfinder", subtitle: "8-week performance", icon: "figure.strengthtraining.traditional", accent: AppColors.primary),
            ProgramCard(title: "Endurance Base", subtitle: "Mileage focus", icon: "map.fill", accent: AppColors.accentGreen),
            ProgramCard(title: "Selection Prep", subtitle: "High-load grind", icon: "flame.fill", accent: AppColors.accentGreenDeep)
        ]
    }
    
    private struct ProgramCard: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let accent: Color
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
                        .foregroundColor(AppColors.textOnLight)
                        
                        Spacer()
                    }
                    Text("Export your workout data")
                        .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(AppColors.accentWarm)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Navigation Bar
    
    // MARK: - Coach Plan Helpers
    
    private func refreshCoachPlan() {
        guard let idString = userSettings.activeProgramID,
              let programId = UUID(uuidString: idString) else {
            coachPlanTitle = nil
            upcomingWorkouts = []
            return
        }
        
        let weeks = programService.getProgramWeeks(programId: programId)
        guard !weeks.isEmpty else {
            coachPlanTitle = programService.getProgramTitle(programId: programId)
            upcomingWorkouts = []
            return
        }
        
        coachPlanTitle = programService.getProgramTitle(programId: programId) ?? "Custom Plan"
        
        // Anchor the schedule to the actual enrollment date so week numbers advance correctly
        // instead of restarting at Week 1 each time this view loads.
        let enrollmentStartDate = LocalProgramStorage.shared.getEnrollmentDate() ?? Date()
        var schedule = ProgramScheduler.generateSchedule(
            for: weeks,
            startDate: enrollmentStartDate,
            preferredDays: normalizedTrainingDays
        )
        
        // Apply light adaptation based on recent feedback.
        schedule = MarchAdaptationEngine.adapt(schedule: schedule)
        
        // Mark completed workouts by ordinal completion count (ordered by date) to avoid duplicate dayNumber issues across weeks.
        let completedWorkouts = WorkoutDataManager.shared.workouts
            .filter { $0.programId == programId.uuidString }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let completedCount = completedWorkouts.count
        
        // Assign completion and lock state: first completedCount items completed, next one unlocked, others locked.
        schedule = schedule.enumerated().map { index, workout in
            var mutable = workout
            mutable.isCompleted = index < completedCount
            // Unlock the next available workout; lock those beyond.
            mutable.isLocked = index > completedCount
            return mutable
        }
        
        // Debug logging to trace mapping
        print("📋 CoachPlan refresh for program \(programId.uuidString)")
        print("📋 Schedule count: \(schedule.count), Completed count: \(completedCount)")
        if !completedWorkouts.isEmpty {
            let sample = completedWorkouts.prefix(5).enumerated().map { idx, w -> String in
                let dateString = w.date?.formatted() ?? "nil"
                return "#\(idx + 1) day=\(w.programWorkoutDay) date=\(dateString)"
            }
            print("📋 Completed sample: \(sample.joined(separator: " | "))")
        }
        let mappedSample = schedule.prefix(5).enumerated().map { idx, w -> String in
            return "#\(idx + 1) title=\(w.title) completed=\(w.isCompleted) dayNumber=\(w.dayNumber?.description ?? "nil") date=\(w.date.formatted())"
        }
        print("📋 Schedule sample: \(mappedSample.joined(separator: " | "))")
        
        // Only surface future items and hide completed; if today is completed, keep it once with a check for immediate feedback
        let today = Calendar.current.startOfDay(for: Date())
        let filtered = schedule.filter { workout in
            if workout.isCompleted {
                // Show completed items only if they are today to give immediate confirmation
                return Calendar.current.isDate(workout.date, inSameDayAs: today)
            }
            // Hide past items entirely and keep upcoming
            return workout.date >= today
        }
        
        let futureWorkouts = filtered.filter { !$0.isCompleted }
        let todayCompleted = filtered.filter { $0.isCompleted }
        
        // Prefer showing future pending workouts; if none, still show today's completed once
        upcomingWorkouts = futureWorkouts.isEmpty ? todayCompleted : futureWorkouts
    }
    
    private func handleCoachPlanWorkoutTap(_ scheduledWorkout: ScheduledWorkout) {
        guard let workoutIdString = scheduledWorkout.workoutID,
              let workoutId = UUID(uuidString: workoutIdString) else {
            print("❌ Missing workout ID for scheduled workout \(scheduledWorkout.title)")
            return
        }
        
        guard let programIdString = userSettings.activeProgramID,
              let programId = UUID(uuidString: programIdString) else {
            print("❌ No active program found for coach plan tap")
            return
        }
        
        Task {
            let programWorkouts = await programService.loadProgramWorkouts(programId: programId)
            guard !programWorkouts.isEmpty else {
                print("❌ No workouts available for program \(programId)")
                return
            }
            
            let completedIndices = WorkoutDataManager.shared.workouts
                .filter { $0.programId == programId.uuidString }
                .compactMap { Int($0.programWorkoutDay) - 1 }
            
            var lastCompletedIndex = -1
            let workoutsWithState: [ProgramWorkoutWithState] = programWorkouts.enumerated().map { index, workout in
                let isCompleted = completedIndices.contains(index)
                
                if isCompleted {
                    lastCompletedIndex = index
                }
                
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
            
            guard let targetWorkout = workoutsWithState.first(where: { $0.workout.id == workoutId }) else {
                print("❌ Scheduled workout id not found in program data")
                return
            }
            
            await MainActor.run {
                selectedUserProgram = programService.userPrograms.first(where: { $0.programId == programId })
                print("📌 Selected programId set for detail: \(programId.uuidString)")
                selectedProgramId = programId
                // Trust the coach plan lock state; allow opening even if ProgramWorkoutsView logic marks locked due to duplicated day numbers.
                var unlocked = targetWorkout
                unlocked = ProgramWorkoutWithState(
                    workout: targetWorkout.workout,
                    weekNumber: targetWorkout.weekNumber,
                    isCompleted: targetWorkout.isCompleted,
                    isLocked: false,
                    completionDate: targetWorkout.completionDate
                )
                selectedProgramWorkout = unlocked
            }
        }
    }
    
    private var normalizedTrainingDays: [Int] {
        let uniqueDays = Array(Set(userSettings.preferredTrainingDays))
        return uniqueDays.isEmpty ? [2, 4, 7] : uniqueDays
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
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            AppColors.textPrimary.opacity(0.2)
                .cornerRadius(8)
        )
    }
}

struct CoachPlanCard: View {
    let programTitle: String
    let preferredDays: [Int]
    let upcomingWorkouts: [ScheduledWorkout]
    let onWorkoutTap: (ScheduledWorkout) -> Void
    
    private var previewWorkouts: [ScheduledWorkout] {
        Array(upcomingWorkouts.prefix(3))
    }
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Coach Plan")
                        .font(.caption)
                        .foregroundColor(AppColors.textPrimary.opacity(0.7))
                    
                    Text(programTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.shield")
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
            }
            
            // Preferred days
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(orderedDays.filter { preferredDays.contains($0) }, id: \.self) { day in
                        Text(shortLabel(for: day))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.textPrimary.opacity(0.15))
                            .foregroundColor(AppColors.textPrimary)
                            .cornerRadius(8)
                    }
                }
            }
            
            Divider().background(AppColors.textPrimary.opacity(0.2))
            
            if previewWorkouts.isEmpty {
                Text("Building your first week...")
                    .font(.caption)
                    .foregroundColor(AppColors.textPrimary.opacity(0.7))
            } else {
                VStack(spacing: 12) {
                    ForEach(previewWorkouts) { workout in
                        CoachPlanScheduleRow(
                            workout: workout,
                            onTap: {
                                onWorkoutTap(workout)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [AppColors.background, AppColors.background.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.textPrimary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private var orderedDays: [Int] {
        [2, 3, 4, 5, 6, 7, 1]
    }
    
    private func shortLabel(for day: Int) -> String {
        let index = (day - 1 + 7) % 7
        return calendar.shortWeekdaySymbols[index]
    }
}

// MARK: - Helpers for Coach / Sessions
extension ImprovedPhoneMainView {
    private var todaysPlannedWorkout: ScheduledWorkout? {
        upcomingWorkouts.first
    }
    
    private var programEyebrow: String {
        if let programIdString = userSettings.activeProgramID,
           let programId = UUID(uuidString: programIdString),
           let title = programService.getProgramTitle(programId: programId) {
            return title.uppercased()
        }
        return userSettings.ruckingGoal.rawValue.uppercased()
    }
    
    private func durationLabel(for workout: ScheduledWorkout) -> String {
        switch workout.workoutType.lowercased() {
        case "recovery ruck": return "40 min est."
        case "pace pusher ruck": return "50 min est."
        case "vertical grind ruck": return "45 min est."
        case "standard test ruck": return "90 min est."
        default: return "60 min est."
        }
    }
    
    private func intensityLabel(for workout: ScheduledWorkout) -> String {
        switch workout.workoutType.lowercased() {
        case "recovery ruck": return "Low"
        case "pace pusher ruck": return "Medium"
        case "vertical grind ruck": return "Medium"
        case "standard test ruck": return "High"
        default: return "Medium"
        }
    }
    
    private func startPlannedWorkout(_ scheduled: ScheduledWorkout) {
        guard let workoutIdString = scheduled.workoutID,
              let _ = UUID(uuidString: workoutIdString),
              let programIdString = userSettings.activeProgramID,
              let programId = UUID(uuidString: programIdString) else {
            return
        }
        
        // Mark program context for save
        workoutManager.setProgramContext(programId: programId, day: scheduled.dayNumber ?? 1)
        selectedWorkoutWeight = UserSettings.shared.defaultRuckWeight
        workoutManager.startWorkout(weight: selectedWorkoutWeight)
        showingActiveWorkout = true
    }
    
    private func startQuickSession(type: SessionType, config: SessionConfiguratorSheet.SessionConfig) {
        // For now we start with default weight; params can be threaded to AudioCoach later.
        workoutManager.setProgramContext(programId: nil, day: nil)
        selectedWorkoutWeight = UserSettings.shared.defaultRuckWeight
        workoutManager.startWorkout(weight: selectedWorkoutWeight)
        showingSessionConfig = false
        showingActiveWorkout = true
    }
}

struct CoachPlanScheduleRow: View {
    let workout: ScheduledWorkout
    let onTap: (() -> Void)?
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()
    
    var body: some View {
        Button(action: {
            if !workout.isLocked {
                onTap?()
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.dateFormatter.string(from: workout.date))
                        .font(.caption)
                        .foregroundColor(foregroundColor)
                    Text(workout.title)
                        .font(.headline)
                        .foregroundColor(titleColor)
                    Text(workout.description)
                        .font(.caption)
                        .foregroundColor(subtitleColor)
                }
                
                Spacer()
                
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            .padding(12)
            .background(
                AppColors.textPrimary.opacity(backgroundOpacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(workout.isLocked ? AppColors.accentWarm.opacity(0.4) : AppColors.textPrimary.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(12)
            .opacity(workout.isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(workout.isLocked)
    }
    
    private var foregroundColor: Color {
        if workout.isCompleted { return .white.opacity(0.5) }
        if workout.isLocked { return .white.opacity(0.5) }
        return .white.opacity(0.7)
    }
    
    private var titleColor: Color {
        if workout.isCompleted { return .white.opacity(0.65) }
        if workout.isLocked { return .white.opacity(0.65) }
        return .white
    }
    
    private var subtitleColor: Color {
        if workout.isCompleted { return .white.opacity(0.45) }
        if workout.isLocked { return .white.opacity(0.45) }
        return .white.opacity(0.7)
    }
    
    private var statusIcon: String {
        if workout.isCompleted { return "checkmark.circle.fill" }
        if workout.isLocked { return "lock.fill" }
        return "chevron.right"
    }
    
    private var statusColor: Color {
        if workout.isCompleted { return AppColors.accentGreen }
        if workout.isLocked { return AppColors.accentWarm }
        return .white.opacity(0.4)
    }
    
    private var backgroundOpacity: Double {
        if workout.isCompleted { return 0.08 }
        if workout.isLocked { return 0.06 }
        return 0.05
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
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                AppColors.textPrimary.opacity(0.3)
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

// MARK: - Session Configurator Sheet
private struct SessionConfiguratorSheet: View {
    @Binding var sessionType: ImprovedPhoneMainView.SessionType?
    let onStart: (ImprovedPhoneMainView.SessionType, SessionConfig) -> Void
    let onCancel: () -> Void
    
    @State private var recoveryDuration: Int = 45
    @State private var paceIntensity: PaceIntensity = .beginner
    @State private var verticalElevation: Int = 500
    @State private var benchmark: BenchmarkOption = .twelveThree
    
    enum PaceIntensity: String, CaseIterable, Identifiable {
        case beginner, pro
        var id: String { rawValue }
        var label: String {
            switch self {
            case .beginner: return "Beginner (15/15)"
            case .pro: return "Pro (10/5)"
            }
        }
    }
    
    enum BenchmarkOption: String, CaseIterable, Identifiable {
        case twelveThree = "12 mi / 3 hr"
        case sixNinety = "6 mi / 1.5 hr"
        var id: String { rawValue }
    }
    
    struct SessionConfig {
        var durationMinutes: Int?
        var paceIntensity: PaceIntensity?
        var elevationFeet: Int?
        var benchmark: BenchmarkOption?
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentTitle)
                    .font(.title2).bold()
                
                configContent
                
                Spacer()
                
                HStack {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Button("Start") {
                        let type = sessionType ?? .justRuck
                        let config = SessionConfig(
                            durationMinutes: type == .recovery ? recoveryDuration : nil,
                            paceIntensity: type == .pacePusher ? paceIntensity : nil,
                            elevationFeet: type == .vertical ? verticalElevation : nil,
                            benchmark: type == .benchmark ? benchmark : nil
                        )
                        onStart(type, config)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var currentTitle: String {
        (sessionType ?? .justRuck).title
    }
    
    @ViewBuilder
    private var configContent: some View {
        switch sessionType ?? .justRuck {
        case .justRuck:
            Text("Open-ended. We’ll record until you stop.")
                .foregroundColor(AppColors.textSecondary)
        case .recovery:
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose duration")
                Picker("", selection: $recoveryDuration) {
                    Text("30 min").tag(30)
                    Text("45 min").tag(45)
                    Text("60 min").tag(60)
                }
                .pickerStyle(.segmented)
            }
        case .pacePusher:
            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity")
                Picker("", selection: $paceIntensity) {
                    ForEach(PaceIntensity.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        case .vertical:
            VStack(alignment: .leading, spacing: 8) {
                Text("Elevation goal (ft)")
                Picker("", selection: $verticalElevation) {
                    Text("500 ft").tag(500)
                    Text("1000 ft").tag(1000)
                }
                .pickerStyle(.segmented)
            }
        case .benchmark:
            VStack(alignment: .leading, spacing: 8) {
                Text("Select benchmark")
                Picker("", selection: $benchmark) {
                    ForEach(BenchmarkOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }
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
