import SwiftUI
import Foundation
import Combine

// MARK: - Main Phone View Coordinator
struct ImprovedPhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var tabSelection: MainTabSelection
    @ObservedObject private var userSettings = UserSettings.shared
    @ObservedObject private var programService = LocalProgramService.shared
    @StateObject private var communityService = CommunityService.shared
    
    // MARK: - State
    @State private var upcomingWorkouts: [ScheduledWorkout] = []
    @State private var coachPlanTitle: String?
    @State private var activeSheet: ActiveSheet? = nil
    @State private var isPresentingWorkoutFlow = false
    @State private var showingWeightSelector = false
    @State private var selectedWorkoutWeight: Double = 0
    @State private var showingActiveWorkout = false
    @State private var selectedProgramWorkout: ProgramWorkoutWithState?
    @State private var selectedUserProgram: UserProgram?
    @State private var selectedProgramId: UUID?
    @State private var pendingShareCode: String?
    @State private var showingGlobalLeaderboard = false
    
    // Tribe tile data
    @State private var nextEventTitle: String?
    @State private var nextEventTime: Date?
    
    // Rankings tile data
    @State private var globalRank: Int?
    
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
    
    // MARK: - Body
    
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
        // Sheet presentations (preserved)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .profile:
                ProfileView()
            case .settings:
                SettingsView()
            case .analytics:
                AnalyticsView(showAllWorkouts: .constant(false))
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
        .sheet(isPresented: $showingGlobalLeaderboard) {
            NavigationView {
                GlobalLeaderboardView()
                    .environmentObject(premiumManager)
            }
        }
        
        // Lifecycle
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
            loadTileData()
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
    
    // MARK: - Main Content View (Bento Grid)
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header — Greeting + Streak
                dashboardHeader
                
                // Section 1: The Hero
                HeroRuckButton {
                    selectedWorkoutWeight = UserSettings.shared.defaultRuckWeight
                    showingWeightSelector = true
                }
                
                // Section 2: The Bento Grid (2x2)
                bentoGrid
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100) // tab bar clearance
        }
    }
    
    // MARK: - Dashboard Header
    
    private var dashboardHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                Text(displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
            
            // Streak badge
            if currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.accentWarm)
                    
                    Text("\(currentStreak)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppColors.accentWarm.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(AppColors.accentWarm.opacity(0.25), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Bento Grid
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private var bentoGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            // Tile 1: Plan
            planTile
            
            // Tile 2: Tribe
            tribeTile
            
            // Tile 3: Challenges
            challengesTile
            
            // Tile 4: Rankings
            rankingsTile
        }
    }
    
    // MARK: - Tile 1: Plan
    
    private var planTile: some View {
        DashboardTile(
            title: "Plan",
            value: planTileValue,
            subtitle: planTileSubtitle,
            icon: "calendar",
            color: AppColors.primary,
            action: {
                tabSelection.selectedTab = .coach
            }
        )
    }
    
    private var planTileValue: String {
        guard let workout = todaysPlannedWorkout else {
            return "No Plan"
        }
        return "Week \(workout.weekNumber)"
    }
    
    private var planTileSubtitle: String {
        guard let workout = todaysPlannedWorkout else {
            return "Tap to browse plans"
        }
        if let day = workout.dayNumber {
            return "Day \(day) • \(workout.workoutType.capitalized)"
        }
        return coachPlanTitle ?? "Active"
    }
    
    // MARK: - Tile 2: Tribe
    
    private var tribeTile: some View {
        DashboardTile(
            title: "Tribe",
            value: tribeTileValue,
            subtitle: tribeTileSubtitle,
            icon: "person.3.fill",
            color: AppColors.accentGreen,
            action: {
                tabSelection.selectedTab = .tribe
            }
        )
    }
    
    private var tribeTileValue: String {
        if nextEventTitle != nil {
            return "Event"
        }
        if let club = communityService.myClubs.first {
            return "\(club.memberCount)"
        }
        return "Join"
    }
    
    private var tribeTileSubtitle: String {
        if let title = nextEventTitle, let time = nextEventTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "\(title) \(formatter.localizedString(for: time, relativeTo: Date()))"
        }
        if let club = communityService.myClubs.first {
            return "\(club.name)"
        }
        return "Find your crew"
    }
    
    // MARK: - Tile 3: Programs
    
    private var challengesTile: some View {
        DashboardTile(
            title: "Programs",
            value: programsTileValue,
            subtitle: programsTileSubtitle,
            icon: "list.clipboard.fill",
            color: AppColors.accentWarm,
            action: {
                activeSheet = .trainingPrograms
            }
        )
    }
    
    private var programsTileValue: String {
        if let workout = todaysPlannedWorkout {
            return "Day \(workout.dayNumber ?? 1)"
        }
        if coachPlanTitle != nil {
            return "Active"
        }
        return "Browse"
    }
    
    private var programsTileSubtitle: String {
        if let title = coachPlanTitle {
            if let workout = todaysPlannedWorkout {
                return "\(title) • Wk \(workout.weekNumber)"
            }
            return title
        }
        return "Find a training plan"
    }
    
    // MARK: - Tile 4: Rankings
    
    private var rankingsTile: some View {
        DashboardTile(
            title: "Rankings",
            value: rankingsTileValue,
            subtitle: rankingsTileSubtitle,
            icon: "chart.bar.fill",
            color: .purple,
            action: {
                showingGlobalLeaderboard = true
            }
        )
    }
    
    private var rankingsTileValue: String {
        if let rank = globalRank {
            return "#\(rank)"
        }
        return "—"
    }
    
    private var rankingsTileSubtitle: String {
        if globalRank != nil {
            return "Global • Distance"
        }
        return "View leaderboard"
    }
    
    // MARK: - Header Helpers
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night"
        }
    }
    
    private var displayName: String {
        if let profile = CommunityService.shared.currentProfile {
            return profile.username
        }
        return userSettings.username ?? "Rucker"
    }
    
    private var currentStreak: Int {
        CommunityService.shared.currentProfile?.currentStreak ?? 0
    }
    
    // MARK: - Tile Data Loading
    
    private func loadTileData() {
        Task {
            // Tribe: fetch next event from primary club
            if communityService.myClubs.isEmpty {
                try? await communityService.loadMyClubs()
            }
            
            if let club = communityService.myClubs.first {
                try? await communityService.loadClubEvents(clubId: club.id)
                
                let cutoff = Date().addingTimeInterval(48 * 60 * 60)
                let upcoming = communityService.clubEvents
                    .filter { $0.startTime > Date() && $0.startTime <= cutoff }
                    .sorted { $0.startTime < $1.startTime }
                    .first
                
                await MainActor.run {
                    nextEventTitle = upcoming?.title
                    nextEventTime = upcoming?.startTime
                }
            }
            
            // Rankings: fetch global leaderboard to find user rank
            if communityService.isAuthenticated {
                _ = try? await communityService.fetchGlobalLeaderboard(type: .distance)
                
                if let userId = communityService.currentProfile?.id {
                    let myEntry = communityService.globalLeaderboard.first { $0.userId == userId }
                    await MainActor.run {
                        globalRank = myEntry?.rank
                    }
                }
            }
        }
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
            .environmentObject(DeepLinkManager())
            .environmentObject(MainTabSelection())
    } else {
        Text("Requires iOS 17.0+")
    }
}
