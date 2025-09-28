//
//  UniversalProgramManager.swift
//  RuckTracker
//
//  Universal program management system that handles all program types
//  with unified enrollment, progress tracking, and recommendations
//

import Foundation
import Combine

@MainActor
class UniversalProgramManager: ObservableObject {
    static let shared = UniversalProgramManager()
    
    private let programService = ProgramService.shared
    private let authService = AuthService() // Assuming you have this
    
    // MARK: - Published State
    @Published var currentPrograms: [ActiveProgramSession] = []
    @Published var recommendedPrograms: [Program] = []
    @Published var programHistory: [CompletedProgramSession] = []
    @Published var nextWorkouts: [UpcomingWorkout] = []
    @Published var isProcessing = false
    
    // Recommendation engine state
    @Published var userFitnessProfile: UserFitnessProfile?
    @Published var programPreferences: ProgramPreferences = ProgramPreferences()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupSubscriptions()
        loadUserProfile()
        
        Task {
            await refreshProgramData()
        }
    }
    
    // MARK: - Subscription Setup
    
    private func setupSubscriptions() {
        // Listen to program service changes
        programService.$userPrograms
            .combineLatest(programService.$programs, programService.$userProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userPrograms, allPrograms, progress in
                self?.updateActiveSessions(userPrograms: userPrograms, allPrograms: allPrograms, progress: progress)
                self?.generateRecommendations(allPrograms: allPrograms, userPrograms: userPrograms)
                self?.updateNextWorkouts()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Program Session Management
    
    func enrollInProgram(
        _ program: Program,
        startingWeight: Double,
        customization: ProgramCustomization? = nil,
        startDate: Date = Date()
    ) async throws -> ActiveProgramSession {
        isProcessing = true
        defer { isProcessing = false }
        
        // Validate enrollment
        try validateEnrollment(program: program, startingWeight: startingWeight)
        
        // Create user program through service
        let userProgram = try await programService.enrollInProgram(
            program,
            startingWeight: startingWeight,
            startDate: startDate
        )
        
        // Create active session
        let session = ActiveProgramSession(
            id: UUID(),
            userProgram: userProgram,
            program: program,
            customization: customization ?? generateDefaultCustomization(for: program),
            startDate: startDate,
            currentPhase: determineCurrentPhase(for: program, week: userProgram.currentWeek),
            nextWorkoutDate: calculateNextWorkoutDate(for: program, currentWeek: userProgram.currentWeek),
            weeklySchedule: generateWeeklySchedule(for: program, customization: customization),
            progressMetrics: ProgramProgressMetrics(),
            adaptations: []
        )
        
        currentPrograms.append(session)
        
        // Update user fitness profile based on enrollment
        await updateFitnessProfile(fromEnrollment: session)
        
        // Generate upcoming workouts
        await generateUpcomingWorkouts(for: session)
        
        print("✅ Enrolled in program: \(program.title)")
        return session
    }
    
    func pauseProgram(_ sessionId: UUID, reason: PausedReason) async throws {
        guard let index = currentPrograms.firstIndex(where: { $0.id == sessionId }) else {
            throw UniversalProgramError.sessionNotFound
        }
        
        currentPrograms[index].isPaused = true
        currentPrograms[index].pausedReason = reason
        currentPrograms[index].pausedDate = Date()
        
        // Remove from upcoming workouts
        nextWorkouts.removeAll { $0.sessionId == sessionId }
        
        print("⏸️ Paused program session")
    }
    
    func resumeProgram(_ sessionId: UUID) async throws {
        guard let index = currentPrograms.firstIndex(where: { $0.id == sessionId }) else {
            throw UniversalProgramError.sessionNotFound
        }
        
        currentPrograms[index].isPaused = false
        currentPrograms[index].pausedReason = nil
        currentPrograms[index].pausedDate = nil
        
        // Recalculate next workout date
        var session = currentPrograms[index]
        session.nextWorkoutDate = calculateNextWorkoutDate(
            for: session.program,
            currentWeek: session.userProgram.currentWeek
        )
        currentPrograms[index] = session
        
        // Regenerate upcoming workouts
        await generateUpcomingWorkouts(for: currentPrograms[index])
        
        print("▶️ Resumed program session")
    }
    
    func completeProgram(_ sessionId: UUID) async throws {
        guard let sessionIndex = currentPrograms.firstIndex(where: { $0.id == sessionId }) else {
            throw UniversalProgramError.sessionNotFound
        }
        
        let session = currentPrograms[sessionIndex]
        
        // Complete in program service
        try await programService.completeProgram(session.userProgram.id)
        
        // Create completed session record
        let completedSession = CompletedProgramSession(
            id: UUID(),
            originalSession: session,
            completedDate: Date(),
            finalMetrics: session.progressMetrics,
            achievements: calculateAchievements(for: session),
            feedback: nil
        )
        
        programHistory.append(completedSession)
        currentPrograms.remove(at: sessionIndex)
        
        // Update fitness profile
        await updateFitnessProfile(fromCompletion: completedSession)
        
        // Generate new recommendations
        await refreshRecommendations()
        
        print("🎉 Completed program: \(session.program.title)")
    }
    
    // MARK: - Workout Management
    
    func recordWorkout(_ workout: CompletedWorkout, for sessionId: UUID) async throws {
        guard let sessionIndex = currentPrograms.firstIndex(where: { $0.id == sessionId }) else {
            throw UniversalProgramError.sessionNotFound
        }
        
        let session = currentPrograms[sessionIndex]
        
        // Create progress record
        let progress = ProgramProgress(
            id: UUID(),
            userId: session.userProgram.userId,
            programId: session.program.id,
            workoutDate: workout.completedDate,
            weekNumber: workout.weekNumber,
            workoutNumber: workout.workoutNumber,
            weightLbs: workout.weightUsed,
            distanceMiles: workout.distanceCompleted,
            durationMinutes: Int(workout.duration / 60),
            completed: true,
            notes: workout.notes,
            heartRateData: workout.heartRateData,
            paceData: workout.paceData
        )
        
        // Record through service
        try await programService.recordProgress(progress)
        
        // Update session metrics
        updateSessionMetrics(session: &currentPrograms[sessionIndex], workout: workout)
        
        // Check for adaptations needed
        let adaptations = analyzePerformance(workout: workout, session: session)
        currentPrograms[sessionIndex].adaptations.append(contentsOf: adaptations)
        
        // Update next workout
        await updateNextWorkoutDate(for: sessionIndex, after: workout)
        
        // Remove completed workout from upcoming
        nextWorkouts.removeAll { $0.sessionId == sessionId && $0.weekNumber == workout.weekNumber && $0.workoutNumber == workout.workoutNumber }
        
        // Generate next workouts if needed
        await generateUpcomingWorkouts(for: currentPrograms[sessionIndex])
        
        print("✅ Recorded workout for week \(workout.weekNumber), workout \(workout.workoutNumber)")
    }
    
    func getNextWorkout(for sessionId: UUID) -> UpcomingWorkout? {
        return nextWorkouts
            .filter { $0.sessionId == sessionId }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first
    }
    
    func getTodaysWorkouts() -> [UpcomingWorkout] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return nextWorkouts.filter { workout in
            workout.scheduledDate >= today && workout.scheduledDate < tomorrow
        }
    }
    
    private func updateNextWorkouts() {
        nextWorkouts.removeAll()
        
        for session in currentPrograms {
            let upcomingWorkouts = generateUpcomingWorkouts(for: session)
            nextWorkouts.append(contentsOf: upcomingWorkouts)
        }
        
        // Sort by scheduled date
        nextWorkouts.sort { $0.scheduledDate < $1.scheduledDate }
    }
    
    private func generateUpcomingWorkouts(for session: ActiveProgramSession) -> [UpcomingWorkout] {
        var workouts: [UpcomingWorkout] = []
        let today = Date()
        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: today) ?? today
        
        var currentDate = today
        var workoutNumber = 1
        
        while currentDate <= endDate {
            let weekNumber = session.userProgram.currentWeek
            let workoutType = determineWorkoutType(for: weekNumber, workoutNumber: workoutNumber, program: session.program)
            
            if workoutType != .rest {
                let workout = UpcomingWorkout(
                    id: UUID(),
                    sessionId: session.id,
                    weekNumber: weekNumber,
                    workoutNumber: workoutNumber,
                    scheduledDate: currentDate,
                    type: workoutType,
                    targetWeight: session.userProgram.currentWeightLbs,
                    targetDistance: 3.0, // Default distance
                    estimatedDuration: 3600.0, // 1 hour default
                    instructions: "Follow your program schedule"
                )
                workouts.append(workout)
            }
            
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            workoutNumber += 1
        }
        
        return workouts
    }
    
    private func determineWorkoutType(for week: Int, workoutNumber: Int, program: Program) -> WorkoutType {
        // Simple logic - can be enhanced
        if workoutNumber % 7 == 0 { return .rest }
        return .ruck
    }
    
    // MARK: - Recommendation Engine
    
    func generateRecommendations(allPrograms: [Program], userPrograms: [UserProgram]) {
        guard let profile = userFitnessProfile else {
            recommendedPrograms = Array(allPrograms.filter { $0.isFeatured }.prefix(3))
            return
        }
        
        var scored: [(Program, Double)] = []
        let activePrograms = Set(userPrograms.filter { $0.isActive }.map { $0.programId })
        let completedPrograms = Set(userPrograms.filter { $0.completedAt != nil }.map { $0.programId })
        
        for program in allPrograms {
            // Skip if already enrolled or completed recently
            if activePrograms.contains(program.id) { continue }
            if completedPrograms.contains(program.id) && 
               userPrograms.first(where: { $0.programId == program.id })?.completedAt?.timeIntervalSinceNow ?? 0 > -30*24*60*60 {
                continue
            }
            
            let score = calculateProgramScore(program: program, profile: profile)
            scored.append((program, score))
        }
        
        recommendedPrograms = scored
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0 }
    }
    
    private func calculateProgramScore(program: Program, profile: UserFitnessProfile) -> Double {
        var score: Double = 0
        
        // Difficulty matching
        let difficultyLevels: [Program.Difficulty] = [.beginner, .intermediate, .advanced, .elite]
        let programLevel = difficultyLevels.firstIndex(of: program.difficulty) ?? 0
        let profileLevel = difficultyLevels.firstIndex(of: profile.currentLevel) ?? 0
        let difficultyGap = abs(programLevel - profileLevel)
        score += max(0, 10 - Double(difficultyGap) * 2)
        
        // Category preference
        if programPreferences.preferredCategories.contains(program.category) {
            score += 15
        }
        
        // Duration preference
        let durationScore = programPreferences.preferredDurationWeeks.map { preferred in
            max(0, 10 - abs(Double(program.durationWeeks - preferred)))
        }.max() ?? 0
        score += durationScore
        
        // Goal alignment
        score += calculateGoalAlignment(program: program, goals: profile.goals)
        
        // Recent activity patterns
        score += calculateActivityPatternAlignment(program: program, profile: profile)
        
        // Variety bonus (encourage trying different types)
        if !profile.completedCategories.contains(program.category) {
            score += 5
        }
        
        return score
    }
    
    private func calculateGoalAlignment(program: Program, goals: [FitnessGoal]) -> Double {
        var alignment: Double = 0
        
        for goal in goals {
            switch goal {
            case .weightLoss:
                if program.category == .fitness || program.difficulty >= .intermediate {
                    alignment += 8
                }
            case .strengthBuilding:
                if program.category == .military || program.difficulty >= .advanced {
                    alignment += 10
                }
            case .enduranceImprovement:
                if program.durationWeeks >= 8 {
                    alignment += 7
                }
            case .militaryPreparation:
                if program.category == .military {
                    alignment += 15
                }
            case .generalFitness:
                alignment += 5 // All programs help with general fitness
            }
        }
        
        return alignment
    }
    
    private func calculateActivityPatternAlignment(program: Program, profile: UserFitnessProfile) -> Double {
        // Consider user's workout frequency, preferred times, etc.
        var alignment: Double = 0
        
        if profile.averageWorkoutsPerWeek >= 4 && program.difficulty >= .intermediate {
            alignment += 5
        }
        
        if profile.averageWorkoutsPerWeek <= 3 && program.difficulty <= .intermediate {
            alignment += 5
        }
        
        return alignment
    }
    
    // MARK: - Progress Analytics
    
    func getProgressAnalytics(for sessionId: UUID) -> ProgramAnalytics? {
        guard let session = currentPrograms.first(where: { $0.id == sessionId }) else {
            return nil
        }
        
        let userProgress = programService.userProgress.filter { $0.programId == session.program.id }
        
        return ProgramAnalytics(
            session: session,
            progressEntries: userProgress,
            workoutConsistency: calculateConsistency(progress: userProgress),
            weightProgression: calculateWeightProgression(progress: userProgress),
            paceImprovement: calculatePaceImprovement(progress: userProgress),
            projectedCompletion: calculateProjectedCompletion(session: session, progress: userProgress)
        )
    }
    
    // MARK: - Data Refresh
    
    func refreshProgramData() async {
        await programService.refreshPrograms()
        await refreshRecommendations()
    }
    
    private func refreshRecommendations() async {
        generateRecommendations(allPrograms: programService.programs, userPrograms: programService.userPrograms)
    }
    
    // MARK: - Private Helper Methods
    
    private func updateActiveSessions(userPrograms: [UserProgram], allPrograms: [Program], progress: [ProgramProgress]) {
        let activeUserPrograms = userPrograms.filter { $0.isActive }
        
        var updatedSessions: [ActiveProgramSession] = []
        
        for userProgram in activeUserPrograms {
            if let existingSession = currentPrograms.first(where: { $0.userProgram.id == userProgram.id }) {
                // Update existing session
                var updated = existingSession
                updated.userProgram = userProgram
                updatedSessions.append(updated)
            } else if let program = allPrograms.first(where: { $0.id == userProgram.programId }) {
                // Create new session for newly discovered active program
                let session = ActiveProgramSession(
                    id: UUID(),
                    userProgram: userProgram,
                    program: program,
                    customization: generateDefaultCustomization(for: program),
                    startDate: userProgram.enrolledAt,
                    currentPhase: determineCurrentPhase(for: program, week: userProgram.currentWeek),
                    nextWorkoutDate: userProgram.nextWorkoutDate ?? Date(),
                    weeklySchedule: generateWeeklySchedule(for: program, customization: nil),
                    progressMetrics: ProgramProgressMetrics(),
                    adaptations: []
                )
                updatedSessions.append(session)
            }
        }
        
        currentPrograms = updatedSessions
    }
    
    private func validateEnrollment(program: Program, startingWeight: Double) throws {
        // Check if weight is reasonable
        if startingWeight < 10 || startingWeight > 200 {
            throw UniversalProgramError.invalidWeight
        }
        
        // Check if already enrolled in same program
        if currentPrograms.contains(where: { $0.program.id == program.id }) {
            throw UniversalProgramError.alreadyEnrolled
        }
        
        // Check if too many active programs (limit to 2)
        if currentPrograms.count >= 2 {
            throw UniversalProgramError.tooManyActivePrograms
        }
    }
    
    private func generateDefaultCustomization(for program: Program) -> ProgramCustomization {
        return ProgramCustomization(
            workoutsPerWeek: program.difficulty >= .advanced ? 4 : 3,
            restDayPreferences: [.sunday],
            intensityModifier: 1.0,
            focusAreas: [.generalEndurance],
            equipmentAvailable: [.ruck, .weights]
        )
    }
    
    private func determineCurrentPhase(for program: Program, week: Int) -> ProgramPhase {
        let totalWeeks = program.durationWeeks
        let progress = Double(week) / Double(totalWeeks)
        
        switch progress {
        case 0..<0.3:
            return .foundation
        case 0.3..<0.7:
            return .building
        case 0.7..<0.9:
            return .peak
        default:
            return .taper
        }
    }
    
    private func calculateNextWorkoutDate(for program: Program, currentWeek: Int) -> Date {
        // Simple calculation - next workout is tomorrow if it's a workout day
        let calendar = Calendar.current
        var nextDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Skip to next workout day based on program schedule
        while calendar.component(.weekday, from: nextDate) == 1 { // Skip Sundays
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func generateWeeklySchedule(for program: Program, customization: ProgramCustomization?) -> WeeklySchedule {
        let workoutsPerWeek = customization?.workoutsPerWeek ?? (program.difficulty >= .advanced ? 4 : 3)
        let restDays = customization?.restDayPreferences ?? [.sunday]
        
        return WeeklySchedule(
            workoutDays: calculateWorkoutDays(workoutsPerWeek: workoutsPerWeek, restDays: restDays),
            restDays: restDays,
            workoutsPerWeek: workoutsPerWeek
        )
    }
    
    private func calculateWorkoutDays(workoutsPerWeek: Int, restDays: [WeekDay]) -> [WeekDay] {
        let allDays: [WeekDay] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        let availableDays = allDays.filter { !restDays.contains($0) }
        
        return Array(availableDays.prefix(workoutsPerWeek))
    }
    
    private func generateUpcomingWorkouts(for session: ActiveProgramSession) async {
        // Generate next 2 weeks of workouts
        let startDate = session.nextWorkoutDate
        var workouts: [UpcomingWorkout] = []
        
        for weekOffset in 0..<2 {
            let targetWeek = session.userProgram.currentWeek + weekOffset
            if targetWeek > session.program.durationWeeks { break }
            
            for (index, workoutDay) in session.weeklySchedule.workoutDays.enumerated() {
                let workoutDate = calculateDateForWorkout(
                    startDate: startDate,
                    weekOffset: weekOffset,
                    workoutDay: workoutDay
                )
                
                let workout = UpcomingWorkout(
                    id: UUID(),
                    sessionId: session.id,
                    weekNumber: targetWeek,
                    workoutNumber: index + 1,
                    scheduledDate: workoutDate,
                    type: determineWorkoutType(week: targetWeek, workout: index + 1, program: session.program),
                    targetWeight: calculateTargetWeight(session: session, week: targetWeek),
                    targetDistance: calculateTargetDistance(session: session, week: targetWeek, workout: index + 1),
                    estimatedDuration: calculateEstimatedDuration(session: session, workout: index + 1),
                    instructions: generateWorkoutInstructions(session: session, week: targetWeek, workout: index + 1)
                )
                
                workouts.append(workout)
            }
        }
        
        // Remove old workouts and add new ones
        nextWorkouts.removeAll { $0.sessionId == session.id }
        nextWorkouts.append(contentsOf: workouts)
        nextWorkouts.sort { $0.scheduledDate < $1.scheduledDate }
    }
    
    private func updateSessionMetrics(session: inout ActiveProgramSession, workout: CompletedWorkout) {
        session.progressMetrics.totalWorkouts += 1
        session.progressMetrics.totalDistance += workout.distanceCompleted
        session.progressMetrics.totalTime += workout.duration
        session.progressMetrics.averageWeight = (session.progressMetrics.averageWeight * Double(session.progressMetrics.totalWorkouts - 1) + workout.weightUsed) / Double(session.progressMetrics.totalWorkouts)
        session.progressMetrics.lastWorkoutDate = workout.completedDate
        
        // Update completion percentage
        let totalWorkouts = session.program.durationWeeks * session.weeklySchedule.workoutsPerWeek
        session.userProgram.completionPercentage = (Double(session.progressMetrics.totalWorkouts) / Double(totalWorkouts)) * 100
    }
    
    private func analyzePerformance(workout: CompletedWorkout, session: ActiveProgramSession) -> [ProgramAdaptation] {
        var adaptations: [ProgramAdaptation] = []
        
        // Check if workout was too easy (completed much faster than expected)
        if let expectedDuration = workout.targetDuration,
           workout.duration < expectedDuration * 0.8 {
            adaptations.append(ProgramAdaptation(
                type: .increaseIntensity,
                reason: "Workout completed significantly faster than target",
                suggestedChange: "Increase weight by 2.5 lbs next workout",
                confidence: 0.8
            ))
        }
        
        // Check if workout was too hard (took much longer or couldn't complete)
        if let expectedDuration = workout.targetDuration,
           workout.duration > expectedDuration * 1.3 {
            adaptations.append(ProgramAdaptation(
                type: .decreaseIntensity,
                reason: "Workout took significantly longer than target",
                suggestedChange: "Reduce weight by 2.5 lbs next workout",
                confidence: 0.7
            ))
        }
        
        return adaptations
    }
    
    private func updateNextWorkoutDate(for sessionIndex: Int, after workout: CompletedWorkout) async {
        let session = currentPrograms[sessionIndex]
        let calendar = Calendar.current
        
        // Find next workout day
        var nextDate = calendar.date(byAdding: .day, value: 1, to: workout.completedDate) ?? Date()
        
        // Skip to next valid workout day
        while !session.weeklySchedule.workoutDays.contains(WeekDay.fromDate(nextDate)) {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        
        var updatedSession = currentPrograms[sessionIndex]
        updatedSession.nextWorkoutDate = nextDate
        updatedSession.userProgram.nextWorkoutDate = nextDate
        currentPrograms[sessionIndex] = updatedSession
    }
    
    private func calculateAchievements(for session: ActiveProgramSession) -> [ProgramAchievement] {
        var achievements: [ProgramAchievement] = []
        
        // Completion achievement
        achievements.append(ProgramAchievement(
            type: .programCompletion,
            title: "Program Graduate",
            description: "Completed \(session.program.title)",
            earnedDate: Date(),
            metadata: ["program_id": session.program.id.uuidString]
        ))
        
        // Consistency achievements
        if session.progressMetrics.consistencyScore >= 0.9 {
            achievements.append(ProgramAchievement(
                type: .consistency,
                title: "Consistency Champion",
                description: "Maintained 90%+ workout consistency",
                earnedDate: Date(),
                metadata: ["consistency": String(session.progressMetrics.consistencyScore)]
            ))
        }
        
        return achievements
    }
    
    // Additional helper methods for workout generation...
    private func calculateDateForWorkout(startDate: Date, weekOffset: Int, workoutDay: WeekDay) -> Date {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startDate) ?? startDate
        return calendar.date(byAdding: .day, value: workoutDay.rawValue - 2, to: weekStart) ?? weekStart
    }
    
    private func determineWorkoutType(week: Int, workout: Int, program: Program) -> WorkoutType {
        // Simple logic - can be made more sophisticated
        if week <= 2 { return .foundation }
        if week >= program.durationWeeks - 1 { return .test }
        return workout % 2 == 0 ? .endurance : .strength
    }
    
    private func calculateTargetWeight(session: ActiveProgramSession, week: Int) -> Double {
        let increment = session.program.difficulty.weightIncrement
        return session.userProgram.startingWeightLbs + (increment * Double(week - 1))
    }
    
    private func calculateTargetDistance(session: ActiveProgramSession, week: Int, workout: Int) -> Double {
        // Base distance varies by workout type and week
        let baseDistance = 2.0 // miles
        let weekMultiplier = 1.0 + (Double(week - 1) * 0.1)
        return baseDistance * weekMultiplier
    }
    
    private func calculateEstimatedDuration(session: ActiveProgramSession, workout: Int) -> TimeInterval {
        // Estimate based on distance and expected pace
        let targetDistance = 2.0 // simplified
        let expectedPaceMinutesPerMile = 15.0 // 15 min/mile pace
        return targetDistance * expectedPaceMinutesPerMile * 60 // convert to seconds
    }
    
    private func generateWorkoutInstructions(session: ActiveProgramSession, week: Int, workout: Int) -> String {
        let weight = calculateTargetWeight(session: session, week: week)
        let distance = calculateTargetDistance(session: session, week: week, workout: workout)
        
        return """
        Week \(week), Workout \(workout)
        
        • Ruck Weight: \(Int(weight)) lbs
        • Target Distance: \(String(format: "%.1f", distance)) miles
        • Maintain steady pace throughout
        • Focus on form and breathing
        
        Remember to warm up before and cool down after!
        """
    }
    
    private func loadUserProfile() {
        // Load from UserDefaults or create default
        if let data = UserDefaults.standard.data(forKey: "user_fitness_profile"),
           let profile = try? JSONDecoder().decode(UserFitnessProfile.self, from: data) {
            userFitnessProfile = profile
        } else {
            userFitnessProfile = UserFitnessProfile.defaultProfile()
        }
    }
    
    private func updateFitnessProfile(fromEnrollment session: ActiveProgramSession) async {
        guard var profile = userFitnessProfile else { return }
        
        // Update based on program choice
        if session.program.difficulty > profile.currentLevel {
            profile.aspirationalLevel = session.program.difficulty
        }
        
        profile.enrollmentHistory.append(session.program.id)
        
        userFitnessProfile = profile
        await saveUserProfile()
    }
    
    private func updateFitnessProfile(fromCompletion session: CompletedProgramSession) async {
        guard var profile = userFitnessProfile else { return }
        
        // Update level based on completion
        if session.originalSession.program.difficulty >= profile.currentLevel {
            profile.currentLevel = session.originalSession.program.difficulty
        }
        
        profile.completedPrograms.append(session.originalSession.program.id)
        profile.completedCategories.insert(session.originalSession.program.category)
        
        userFitnessProfile = profile
        await saveUserProfile()
    }
    
    private func saveUserProfile() async {
        guard let profile = userFitnessProfile,
              let data = try? JSONEncoder().encode(profile) else { return }
        
        UserDefaults.standard.set(data, forKey: "user_fitness_profile")
    }
    
    // Analytics helper methods
    private func calculateConsistency(progress: [ProgramProgress]) -> Double {
        // Calculate workout consistency over time
        guard !progress.isEmpty else { return 0 }
        
        let totalExpectedWorkouts = progress.count + 2 // Assuming some missed
        let completedWorkouts = progress.filter { $0.completed }.count
        
        return Double(completedWorkouts) / Double(totalExpectedWorkouts)
    }
    
    private func calculateWeightProgression(progress: [ProgramProgress]) -> [WeightProgressPoint] {
        return progress
            .sorted { $0.workoutDate < $1.workoutDate }
            .map { WeightProgressPoint(date: $0.workoutDate, weight: $0.weightLbs) }
    }
    
    private func calculatePaceImprovement(progress: [ProgramProgress]) -> [PaceProgressPoint] {
        return progress
            .compactMap { entry in
                guard let paceData = entry.paceData else { return nil }
                return PaceProgressPoint(date: entry.workoutDate, averagePace: paceData.averageMinutesPerMile)
            }
            .sorted { $0.date < $1.date }
    }
    
    private func calculateProjectedCompletion(session: ActiveProgramSession, progress: [ProgramProgress]) -> Date? {
        let consistency = calculateConsistency(progress: progress)
        let remainingWeeks = session.program.durationWeeks - session.userProgram.currentWeek
        let expectedWeeksToComplete = Double(remainingWeeks) / consistency
        
        return Calendar.current.date(byAdding: .weekOfYear, value: Int(expectedWeeksToComplete), to: Date())
    }
}

// MARK: - Supporting Data Models

struct ActiveProgramSession: Identifiable, Codable {
    let id: UUID
    var userProgram: UserProgram
    let program: Program
    let customization: ProgramCustomization
    let startDate: Date
    var currentPhase: ProgramPhase
    var nextWorkoutDate: Date
    let weeklySchedule: WeeklySchedule
    var progressMetrics: ProgramProgressMetrics
    var adaptations: [ProgramAdaptation]
    var isPaused: Bool = false
    var pausedReason: PausedReason?
    var pausedDate: Date?
}

struct CompletedProgramSession: Identifiable, Codable {
    let id: UUID
    let originalSession: ActiveProgramSession
    let completedDate: Date
    let finalMetrics: ProgramProgressMetrics
    let achievements: [ProgramAchievement]
    var feedback: ProgramFeedback?
}

struct ProgramCustomization: Codable {
    let workoutsPerWeek: Int
    let restDayPreferences: [WeekDay]
    let intensityModifier: Double
    let focusAreas: [FocusArea]
    let equipmentAvailable: [Equipment]
}

struct WeeklySchedule: Codable {
    let workoutDays: [WeekDay]
    let restDays: [WeekDay]
    let workoutsPerWeek: Int
}

struct ProgramProgressMetrics: Codable {
    var totalWorkouts: Int = 0
    var totalDistance: Double = 0
    var totalTime: TimeInterval = 0
    var averageWeight: Double = 0
    var lastWorkoutDate: Date?
    var consistencyScore: Double = 0
    var strengthGains: Double = 0
    var enduranceGains: Double = 0
}

struct ProgramAdaptation: Codable {
    let type: AdaptationType
    let reason: String
    let suggestedChange: String
    let confidence: Double
}

struct UpcomingWorkout: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let weekNumber: Int
    let workoutNumber: Int
    let scheduledDate: Date
    let type: WorkoutType
    let targetWeight: Double
    let targetDistance: Double
    let estimatedDuration: TimeInterval
    let instructions: String
}

struct CompletedWorkout: Codable {
    let completedDate: Date
    let weekNumber: Int
    let workoutNumber: Int
    let weightUsed: Double
    let distanceCompleted: Double
    let duration: TimeInterval
    let notes: String?
    let heartRateData: HeartRateData?
    let paceData: PaceData?
    let targetDuration: TimeInterval?
    
    // MARK: - Integration Support
    
    var encodedData: String {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

struct UserFitnessProfile: Codable {
    var currentLevel: Program.Difficulty
    var aspirationalLevel: Program.Difficulty?
    var goals: [FitnessGoal]
    var averageWorkoutsPerWeek: Int
    var completedPrograms: [UUID]
    var completedCategories: Set<Program.Category>
    var enrollmentHistory: [UUID]
    var preferredWorkoutTimes: [TimeOfDay]
    var injuryHistory: [InjuryRecord]
    var equipmentAccess: [Equipment]
    
    static func defaultProfile() -> UserFitnessProfile {
        return UserFitnessProfile(
            currentLevel: .beginner,
            aspirationalLevel: nil,
            goals: [.generalFitness],
            averageWorkoutsPerWeek: 3,
            completedPrograms: [],
            completedCategories: [],
            enrollmentHistory: [],
            preferredWorkoutTimes: [.morning],
            injuryHistory: [],
            equipmentAccess: [.ruck]
        )
    }
}

struct ProgramPreferences: Codable {
    var preferredCategories: [Program.Category] = []
    var preferredDurationWeeks: [Int] = [8, 12, 16]
    var maxConcurrentPrograms: Int = 2
    var autoProgressionEnabled: Bool = true
    var notificationsEnabled: Bool = true
    var reminderTime: TimeOfDay = .morning
}

struct ProgramAnalytics {
    let session: ActiveProgramSession
    let progressEntries: [ProgramProgress]
    let workoutConsistency: Double
    let weightProgression: [WeightProgressPoint]
    let paceImprovement: [PaceProgressPoint]
    let projectedCompletion: Date?
}

struct WeightProgressPoint: Codable {
    let date: Date
    let weight: Double
}

struct PaceProgressPoint: Codable {
    let date: Date
    let averagePace: Double
}

struct ProgramAchievement: Codable {
    let type: AchievementType
    let title: String
    let description: String
    let earnedDate: Date
    let metadata: [String: String]
}

struct ProgramFeedback: Codable {
    let overallRating: Int // 1-5
    let difficultyRating: Int // 1-5
    let enjoymentRating: Int // 1-5
    let wouldRecommend: Bool
    let comments: String?
    let suggestedImprovements: [String]
}


struct InjuryRecord: Codable {
    let type: InjuryType
    let date: Date
    let severity: InjurySeverity
    let affectedAreas: [BodyArea]
    let recoveryTime: TimeInterval?
}

// MARK: - Enums

enum ProgramPhase: String, Codable, CaseIterable {
    case foundation = "Foundation"
    case building = "Building"
    case peak = "Peak"
    case taper = "Taper"
}

enum WeekDay: Int, Codable, CaseIterable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1
    
    static func fromDate(_ date: Date) -> WeekDay {
        let weekday = Calendar.current.component(.weekday, from: date)
        return WeekDay(rawValue: weekday) ?? .monday
    }
}

enum FocusArea: String, Codable, CaseIterable {
    case generalEndurance = "General Endurance"
    case strengthBuilding = "Strength Building"
    case speedDevelopment = "Speed Development"
    case powerEndurance = "Power Endurance"
    case militarySpecific = "Military Specific"
}

enum Equipment: String, Codable, CaseIterable {
    case ruck = "Ruck"
    case weights = "Weights"
    case pullupBar = "Pull-up Bar"
    case resistance = "Resistance Bands"
    case cardio = "Cardio Equipment"
}

enum AdaptationType: String, Codable, CaseIterable {
    case increaseIntensity = "Increase Intensity"
    case decreaseIntensity = "Decrease Intensity"
    case adjustVolume = "Adjust Volume"
    case modifySchedule = "Modify Schedule"
    case restRecommended = "Rest Recommended"
}

enum WorkoutType: String, Codable, CaseIterable {
    case foundation = "Foundation"
    case endurance = "Endurance"
    case strength = "Strength"
    case speed = "Speed"
    case recovery = "Recovery"
    case test = "Test"
    case rest = "Rest"
    case ruck = "Ruck"
}

enum PausedReason: String, Codable, CaseIterable {
    case injury = "Injury"
    case illness = "Illness"
    case travel = "Travel"
    case schedule = "Schedule Conflict"
    case motivation = "Low Motivation"
    case other = "Other"
}

enum FitnessGoal: String, Codable, CaseIterable {
    case weightLoss = "Weight Loss"
    case strengthBuilding = "Strength Building"
    case enduranceImprovement = "Endurance Improvement"
    case militaryPreparation = "Military Preparation"
    case generalFitness = "General Fitness"
}

enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
}

enum AchievementType: String, Codable, CaseIterable {
    case programCompletion = "Program Completion"
    case consistency = "Consistency"
    case strengthMilestone = "Strength Milestone"
    case enduranceMilestone = "Endurance Milestone"
    case streak = "Streak"
}

enum InjuryType: String, Codable, CaseIterable {
    case acute = "Acute"
    case overuse = "Overuse"
    case chronic = "Chronic"
}

enum InjurySeverity: String, Codable, CaseIterable {
    case minor = "Minor"
    case moderate = "Moderate"
    case severe = "Severe"
}

enum BodyArea: String, Codable, CaseIterable {
    case back = "Back"
    case shoulders = "Shoulders"
    case knees = "Knees"
    case ankles = "Ankles"
    case feet = "Feet"
    case hips = "Hips"
}


// MARK: - Universal Program Manager Errors

enum UniversalProgramError: Error {
    case sessionNotFound
    case alreadyEnrolled
    case tooManyActivePrograms
    case invalidWeight
    case profileNotFound
    case adaptationFailed
    
    var localizedDescription: String {
        switch self {
        case .sessionNotFound:
            return "Program session not found"
        case .alreadyEnrolled:
            return "Already enrolled in this program"
        case .tooManyActivePrograms:
            return "Too many active programs (maximum 2)"
        case .invalidWeight:
            return "Invalid weight value"
        case .profileNotFound:
            return "User fitness profile not found"
        case .adaptationFailed:
            return "Failed to apply program adaptation"
        }
    }
}
