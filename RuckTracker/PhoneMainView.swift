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
                finalRuckWeight: workoutManager.finalRuckWeight,
                finalElevationGain: workoutManager.finalElevationGain
            )
            .environmentObject(workoutManager)
        }
        .sheet(isPresented: $showingActiveWorkout) {
            ActiveWorkoutFullScreenView()
                .environmentObject(workoutManager)
        }
        .sheet(isPresented: $showingWeightSelector) {
            WorkoutWeightSelector(
                selectedWeight: $selectedWorkoutWeight,
                isPresented: $showingWeightSelector,
                recommendedWeight: nil,
                context: "Open Goal Ruck",
                onStart: {
                    workoutManager.setProgramContext(programId: nil, day: nil)
                    workoutManager.startWorkout(weight: selectedWorkoutWeight)
                    showingActiveWorkout = true
                }
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
                // 1. Hero Button
                HeroRuckButton {
                    selectedWorkoutWeight = UserSettings.shared.defaultRuckWeight
                    showingWeightSelector = true
                }
                
                // 2. Active Program Card (Conditional)
                activeProgramCard
                
                // 3. Recent Activity
                recentActivitySection
                
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 20)
        }
        .background(Color.clear)
    }
    
    // MARK: - Active Program Card
    
    private var activeProgramCard: some View {
        Group {
            if let planned = todaysPlannedWorkout {
                // Active program — show next workout
                Button {
                    startPlannedWorkout(planned)
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(programEyebrow)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                            
                            Text(planned.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
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
                            .padding(.top, 4)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppColors.primary.opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(color: AppColors.primary.opacity(0.25), radius: 16, x: 0, y: 6)
                    )
                }
                .buttonStyle(.plain)
            } else {
                // No active program — prompt to start one
                Button {
                    activeSheet = .trainingPrograms
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start a Training Plan")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Follow a structured program")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.textSecondary.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        Group {
            if let lastWorkout = workoutDataManager.workouts.sorted(by: {
                ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
            }).first {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last Ruck")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    lastRuckCard(lastWorkout)
                }
            }
        }
    }
    
    private func lastRuckCard(_ workout: WorkoutEntity) -> some View {
        Button {
            activeSheet = .workoutHistory
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accentGreen.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.accentGreen)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    if let date = workout.date {
                        Text(date, style: .relative)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack(spacing: 16) {
                        Label(String(format: "%.1f mi", workout.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Label(formattedDuration(workout.duration), systemImage: "clock")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        if workout.ruckWeight > 0 {
                            Label("\(Int(workout.ruckWeight)) lbs", systemImage: "scalemass")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.4))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.textSecondary.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
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
        
        let enrollmentStartDate = LocalProgramStorage.shared.getEnrollmentDate() ?? Date()
        var schedule = ProgramScheduler.generateSchedule(
            for: weeks,
            startDate: enrollmentStartDate,
            preferredDays: normalizedTrainingDays
        )
        
        schedule = MarchAdaptationEngine.adapt(schedule: schedule)
        
        let completedWorkouts = WorkoutDataManager.shared.workouts
            .filter { $0.programId == programId.uuidString }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let completedCount = completedWorkouts.count
        
        schedule = schedule.enumerated().map { index, workout in
            var mutable = workout
            mutable.isCompleted = index < completedCount
            mutable.isLocked = index > completedCount
            return mutable
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let filtered = schedule.filter { workout in
            if workout.isCompleted {
                return Calendar.current.isDate(workout.date, inSameDayAs: today)
            }
            return workout.date >= today
        }
        
        let futureWorkouts = filtered.filter { !$0.isCompleted }
        let todayCompleted = filtered.filter { $0.isCompleted }
        
        upcomingWorkouts = futureWorkouts.isEmpty ? todayCompleted : futureWorkouts
    }
    
    private func handleCoachPlanWorkoutTap(_ scheduledWorkout: ScheduledWorkout) {
        guard let workoutIdString = scheduledWorkout.workoutID,
              let workoutId = UUID(uuidString: workoutIdString) else {
            return
        }
        
        guard let programIdString = userSettings.activeProgramID,
              let programId = UUID(uuidString: programIdString) else {
            return
        }
        
        Task {
            let programWorkouts = await programService.loadProgramWorkouts(programId: programId)
            guard !programWorkouts.isEmpty else { return }
            
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
                return
            }
            
            await MainActor.run {
                selectedUserProgram = programService.userPrograms.first(where: { $0.programId == programId })
                selectedProgramId = programId
                var unlocked = ProgramWorkoutWithState(
                    workout: targetWorkout.workout,
                    weekNumber: targetWorkout.weekNumber,
                    isCompleted: targetWorkout.isCompleted,
                    isLocked: false,
                    completionDate: targetWorkout.completionDate
                )
                _ = unlocked
                selectedProgramWorkout = ProgramWorkoutWithState(
                    workout: targetWorkout.workout,
                    weekNumber: targetWorkout.weekNumber,
                    isCompleted: targetWorkout.isCompleted,
                    isLocked: false,
                    completionDate: targetWorkout.completionDate
                )
            }
        }
    }
    
    private var normalizedTrainingDays: [Int] {
        let uniqueDays = Array(Set(userSettings.preferredTrainingDays))
        return uniqueDays.isEmpty ? [2, 4, 7] : uniqueDays
    }
}

// MARK: - Helpers for Coach / Sessions
extension ImprovedPhoneMainView {
    fileprivate var todaysPlannedWorkout: ScheduledWorkout? {
        upcomingWorkouts.first
    }
    
    fileprivate var programEyebrow: String {
        if let programIdString = userSettings.activeProgramID,
           let programId = UUID(uuidString: programIdString),
           let title = programService.getProgramTitle(programId: programId) {
            return title.uppercased()
        }
        return userSettings.ruckingGoal.rawValue.uppercased()
    }
    
    fileprivate func durationLabel(for workout: ScheduledWorkout) -> String {
        switch workout.workoutType.lowercased() {
        case "recovery ruck": return "40 min est."
        case "pace pusher ruck": return "50 min est."
        case "vertical grind ruck": return "45 min est."
        case "standard test ruck": return "90 min est."
        default: return "60 min est."
        }
    }
    
    fileprivate func intensityLabel(for workout: ScheduledWorkout) -> String {
        switch workout.workoutType.lowercased() {
        case "recovery ruck": return "Low"
        case "pace pusher ruck": return "Medium"
        case "vertical grind ruck": return "Medium"
        case "standard test ruck": return "High"
        default: return "Medium"
        }
    }
    
    fileprivate func startPlannedWorkout(_ scheduled: ScheduledWorkout) {
        guard let workoutIdString = scheduled.workoutID,
              let _ = UUID(uuidString: workoutIdString),
              let programIdString = userSettings.activeProgramID,
              let programId = UUID(uuidString: programIdString) else {
            return
        }
        
        workoutManager.setProgramContext(programId: programId, day: scheduled.dayNumber ?? 1)
        selectedWorkoutWeight = UserSettings.shared.defaultRuckWeight
        workoutManager.startWorkout(weight: selectedWorkoutWeight)
        showingActiveWorkout = true
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
