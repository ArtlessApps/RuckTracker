import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var workoutDataManager: WorkoutDataManager
    
    @ObservedObject private var userSettings = UserSettings.shared
    @ObservedObject private var programService = LocalProgramService.shared
    
    @AppStorage("hasCompletedPhoneOnboarding") private var hasCompletedPhoneOnboarding = true
    
    @State private var planTitle: String?
    @State private var schedule: [ScheduledWorkout] = []
    @State private var loadError: String?
    @State private var showingActiveWorkout = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                content
            }
            .navigationTitle("My Training Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Switch Goal") {
                        // Kicks the user back into the personalized onboarding flow (ContentView observes this).
                        hasCompletedPhoneOnboarding = false
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear { refreshPlan() }
        .onChange(of: userSettings.activeProgramID) { _, _ in refreshPlan() }
        .onChange(of: workoutDataManager.workouts.count) { _, _ in refreshPlan() }
        .sheet(isPresented: $showingActiveWorkout) {
            ActiveWorkoutFullScreenView()
                .environmentObject(workoutManager)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if let loadError {
            errorState(message: loadError)
        } else if userSettings.activeProgramID == nil {
            emptyState
        } else if schedule.isEmpty {
            loadingOrEmptyPlanState
        } else {
            planScheduleView
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            MARCHBranding(logoSize: .large)
                .padding(.bottom, 4)
            
            Text("Build your personalized plan to see your scheduled workouts here.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            
            Button {
                hasCompletedPhoneOnboarding = false
            } label: {
                Text("Build My Plan")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var loadingOrEmptyPlanState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(AppColors.primary)
            Text("Loading your plan…")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Couldn't load your plan")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Try Again") { refreshPlan() }
                .foregroundColor(AppColors.primary)
            Spacer()
        }
    }
    
    private var planScheduleView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerCard
                
                VStack(spacing: 12) {
                    ForEach(groupedWeeks, id: \.weekNumber) { section in
                        weekSection(section)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Coach Plan")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Text(planTitle ?? "Personalized Plan")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: 10) {
                headerPill(title: "Goal", value: userSettings.ruckingGoal.rawValue)
                headerPill(title: "Days", value: preferredDaysLabel)
                headerPill(title: "Done", value: "\(completedCount)/\(schedule.count)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.textSecondary.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private func headerPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary.opacity(0.8))
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.background.opacity(0.35))
        .cornerRadius(12)
    }
    
    private func weekSection(_ section: WeekSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Week \(section.weekNumber)")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 10) {
                ForEach(section.workouts) { workout in
                    planRow(workout)
                }
            }
        }
    }
    
    private func planRow(_ workout: ScheduledWorkout) -> some View {
        let accent = accentColor(for: workout.workoutType)
        
        return Button {
            // Minimal interaction for now: if unlocked, start the workout immediately.
            // (This mirrors the "today" start flow in `ImprovedPhoneMainView`.)
            guard !workout.isLocked,
                  let programIdString = userSettings.activeProgramID,
                  let programId = UUID(uuidString: programIdString) else { return }
            
            workoutManager.setProgramContext(programId: programId, day: workout.dayNumber ?? 1)
            workoutManager.startWorkout(weight: UserSettings.shared.defaultRuckWeight)
            showingActiveWorkout = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateLabel(for: workout.date))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(workout.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(workout.isLocked ? AppColors.textSecondary : AppColors.textPrimary)
                    
                    Text(workout.description)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary.opacity(0.9))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    statusBadge(for: workout)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary.opacity(workout.isLocked ? 0.35 : 0.9))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.background.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(accent.opacity(workout.isLocked ? 0.15 : 0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(workout.isLocked || workout.isCompleted)
        .opacity(workout.isLocked ? 0.6 : 1.0)
    }
    
    private func statusBadge(for workout: ScheduledWorkout) -> some View {
        let text: String
        let bg: Color
        let fg: Color
        
        if workout.isCompleted {
            text = "DONE"
            bg = AppColors.successGreen.opacity(0.2)
            fg = AppColors.successGreen
        } else if workout.isLocked {
            text = "LOCKED"
            bg = AppColors.textSecondary.opacity(0.15)
            fg = AppColors.textSecondary
        } else if Calendar.current.isDateInToday(workout.date) {
            text = "TODAY"
            bg = AppColors.primary.opacity(0.22)
            fg = AppColors.primary
        } else {
            text = "UP NEXT"
            bg = AppColors.accentTeal.opacity(0.18)
            fg = AppColors.accentTeal
        }
        
        return Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(bg)
            .foregroundColor(fg)
            .cornerRadius(10)
    }
    
    // MARK: - Data
    
    private struct WeekSection {
        let weekNumber: Int
        let workouts: [ScheduledWorkout]
    }
    
    private var groupedWeeks: [WeekSection] {
        let grouped = Dictionary(grouping: schedule) { $0.weekNumber }
        return grouped.keys.sorted().map { key in
            WeekSection(
                weekNumber: key,
                workouts: (grouped[key] ?? []).sorted { $0.date < $1.date }
            )
        }
    }
    
    private var completedCount: Int {
        schedule.filter { $0.isCompleted }.count
    }
    
    private var preferredDaysLabel: String {
        let orderedDays = [2, 3, 4, 5, 6, 7, 1] // Mon...Sun (Calendar weekday ints)
        let days = orderedDays.filter { normalizedTrainingDays.contains($0) }
        let symbols = Calendar.current.shortWeekdaySymbols
        let labels = days.map { day in
            let idx = (day - 1 + 7) % 7
            return symbols[idx]
        }
        return labels.joined(separator: " ")
    }
    
    private var normalizedTrainingDays: [Int] {
        let uniqueDays = Array(Set(userSettings.preferredTrainingDays))
        return uniqueDays.isEmpty ? [2, 4, 7] : uniqueDays
    }
    
    private func refreshPlan() {
        loadError = nil
        schedule = []
        planTitle = nil
        
        guard let idString = userSettings.activeProgramID,
              let programId = UUID(uuidString: idString) else {
            return
        }
        
        let weeks = programService.getProgramWeeks(programId: programId)
        guard !weeks.isEmpty else {
            planTitle = programService.getProgramTitle(programId: programId)
            return
        }
        
        planTitle = programService.getProgramTitle(programId: programId) ?? "Personalized Plan"
        
        let enrollmentStartDate = LocalProgramStorage.shared.getEnrollmentDate() ?? Date()
        var generated = ProgramScheduler.generateSchedule(
            for: weeks,
            startDate: enrollmentStartDate,
            preferredDays: normalizedTrainingDays
        )
        
        generated = MarchAdaptationEngine.adapt(schedule: generated)
        
        // Mark completions/locking based on workout count completed for this program.
        let completedWorkouts = workoutDataManager.workouts
            .filter { $0.programId == programId.uuidString }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let completed = completedWorkouts.count
        
        generated = generated.enumerated().map { index, workout in
            var mutable = workout
            mutable.isCompleted = index < completed
            mutable.isLocked = index > completed
            return mutable
        }
        
        schedule = generated
    }
    
    // MARK: - Styling Helpers
    
    private func accentColor(for workoutType: String) -> Color {
        let type = workoutType.lowercased()
        if type.contains("recovery") { return AppColors.accentGreenLight }
        if type.contains("pace") { return AppColors.accentGreenDeep }
        if type.contains("vertical") { return AppColors.accentWarm }
        if type.contains("test") { return AppColors.accentTeal }
        if type.contains("endurance") { return AppColors.accentTealDeep }
        return AppColors.primary
    }
    
    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        let base = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) { return "\(base) • Today" }
        if Calendar.current.isDateInTomorrow(date) { return "\(base) • Tomorrow" }
        return base
    }
}

#Preview {
    PlanView()
        .environmentObject(WorkoutManager())
        .environmentObject(WorkoutDataManager.shared)
}

