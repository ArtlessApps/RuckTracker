//
//  ProgramWorkflowEngine.swift
//  RuckTracker
//
//  Dynamic workout generation and progressive programming system
//  Handles adaptive algorithms and intelligent workout planning
//

import Foundation
import Combine

@MainActor
class ProgramWorkflowEngine: ObservableObject {
    static let shared = ProgramWorkflowEngine()
    
    private let universalManager = UniversalProgramManager.shared
    private let programService = ProgramService.shared
    
    // MARK: - Published State
    @Published var workflowTemplates: [WorkflowTemplate] = []
    @Published var activeWorkflows: [ActiveWorkflow] = []
    @Published var progressionRules: [ProgressionRule] = []
    @Published var adaptationHistory: [AdaptationRecord] = []
    @Published var isGenerating = false
    
    // Algorithm configuration
    private let algorithmConfig = AlgorithmConfiguration()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupWorkflowTemplates()
        setupProgressionRules()
        setupSubscriptions()
        loadAdaptationHistory()
    }
    
    // MARK: - Subscription Setup
    
    private func setupSubscriptions() {
        universalManager.$currentPrograms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] programs in
                self?.updateActiveWorkflows(for: programs)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Workflow Generation
    
    func generateWorkflow(for session: ActiveProgramSession) async -> GeneratedWorkflow {
        isGenerating = true
        defer { isGenerating = false }
        
        print("🔄 Generating workflow for program: \(session.program.title)")
        
        // Get or create workflow template
        let template = getWorkflowTemplate(for: session.program)
        
        // Generate progressive workout plan
        let workoutPlan = await generateProgressiveWorkouts(
            template: template,
            session: session,
            startWeek: session.userProgram.currentWeek
        )
        
        // Apply personalization
        let personalizedPlan = await personalizeWorkouts(
            plan: workoutPlan,
            session: session
        )
        
        // Create workflow instance
        let workflow = GeneratedWorkflow(
            id: UUID(),
            sessionId: session.id,
            template: template,
            generatedDate: Date(),
            workouts: personalizedPlan,
            progressionStrategy: determineProgressionStrategy(for: session),
            adaptationRules: getApplicableAdaptations(for: session),
            validityPeriod: .weeks(4) // Regenerate every 4 weeks
        )
        
        // Cache for performance
        await cacheWorkflow(workflow)
        
        print("✅ Generated \(personalizedPlan.count) workouts for next 4 weeks")
        return workflow
    }
    
    func regenerateWorkflow(for sessionId: UUID, reason: RegenerationReason) async throws -> GeneratedWorkflow {
        guard let session = universalManager.currentPrograms.first(where: { $0.id == sessionId }) else {
            throw WorkflowEngineError.sessionNotFound
        }
        
        print("🔄 Regenerating workflow due to: \(reason.rawValue)")
        
        // Record regeneration reason
        let adaptationRecord = AdaptationRecord(
            sessionId: sessionId,
            reason: reason,
            timestamp: Date(),
            previousPerformance: getRecentPerformance(for: sessionId),
            appliedChanges: []
        )
        adaptationHistory.append(adaptationRecord)
        
        // Generate new workflow with adaptations
        return await generateWorkflow(for: session)
    }
    
    // MARK: - Progressive Workout Generation
    
    private func generateProgressiveWorkouts(
        template: WorkflowTemplate,
        session: ActiveProgramSession,
        startWeek: Int
    ) async -> [PlannedWorkout] {
        var workouts: [PlannedWorkout] = []
        let totalWeeks = min(4, session.program.durationWeeks - startWeek + 1)
        
        for weekOffset in 0..<totalWeeks {
            let currentWeek = startWeek + weekOffset
            let weekWorkouts = await generateWeekWorkouts(
                template: template,
                session: session,
                week: currentWeek,
                weekOffset: weekOffset
            )
            workouts.append(contentsOf: weekWorkouts)
        }
        
        return workouts
    }
    
    private func generateWeekWorkouts(
        template: WorkflowTemplate,
        session: ActiveProgramSession,
        week: Int,
        weekOffset: Int
    ) async -> [PlannedWorkout] {
        var weekWorkouts: [PlannedWorkout] = []
        let phase = determinePhase(week: week, totalWeeks: session.program.durationWeeks)
        
        // Get base workout pattern for this week
        let weekPattern = template.getWeekPattern(for: phase, week: week)
        
        for (dayIndex, workoutDay) in session.weeklySchedule.workoutDays.enumerated() {
            let workoutDate = calculateWorkoutDate(
                startWeek: session.userProgram.enrolledAt,
                weekOffset: weekOffset,
                workoutDay: workoutDay
            )
            
            let workout = await generateSingleWorkout(
                template: template,
                session: session,
                week: week,
                dayIndex: dayIndex,
                workoutDate: workoutDate,
                phase: phase,
                weekPattern: weekPattern
            )
            
            weekWorkouts.append(workout)
        }
        
        return weekWorkouts
    }
    
    private func generateSingleWorkout(
        template: WorkflowTemplate,
        session: ActiveProgramSession,
        week: Int,
        dayIndex: Int,
        workoutDate: Date,
        phase: ProgramPhase,
        weekPattern: WeekPattern
    ) async -> PlannedWorkout {
        
        // Determine workout type based on pattern and day
        let workoutType = determineWorkoutType(
            dayIndex: dayIndex,
            week: week,
            phase: phase,
            pattern: weekPattern
        )
        
        // Calculate progressive parameters
        let parameters = await calculateWorkoutParameters(
            session: session,
            week: week,
            workoutType: workoutType,
            template: template
        )
        
        // Generate workout structure
        let structure = generateWorkoutStructure(
            type: workoutType,
            parameters: parameters,
            template: template
        )
        
        // Create planned workout
        return PlannedWorkout(
            id: UUID(),
            sessionId: session.id,
            week: week,
            dayIndex: dayIndex + 1,
            scheduledDate: workoutDate,
            type: workoutType,
            phase: phase,
            parameters: parameters,
            structure: structure,
            estimatedDuration: calculateEstimatedDuration(structure: structure),
            difficulty: calculateWorkoutDifficulty(parameters: parameters, type: workoutType),
            prerequisites: determinePrerequisites(week: week, dayIndex: dayIndex),
            adaptationFlags: []
        )
    }
    
    // MARK: - Helper Methods
    
    private func setupWorkflowTemplates() {
        workflowTemplates = [
            createMilitaryFoundationTemplate(),
            createRangerChallengeTemplate(),
            createSelectionPrepTemplate(),
            createMaintenanceTemplate()
        ]
    }
    
    private func setupProgressionRules() {
        progressionRules = [
            ProgressionRule(
                condition: .weeklyConsistency(threshold: 0.8),
                action: .increaseWeight(amount: 2.5),
                priority: .high
            ),
            ProgressionRule(
                condition: .averageCompletionTime(ratio: 0.85),
                action: .increaseIntensity(multiplier: 1.1),
                priority: .medium
            ),
            ProgressionRule(
                condition: .heartRateRecovery(threshold: 0.7),
                action: .increaseDistance(multiplier: 1.1),
                priority: .medium
            ),
            ProgressionRule(
                condition: .missedWorkouts(count: 2),
                action: .decreaseIntensity(multiplier: 0.9),
                priority: .high
            )
        ]
    }
    
    private func getWorkflowTemplate(for program: Program) -> WorkflowTemplate {
        return workflowTemplates.first { $0.programCategory == program.category && $0.difficulty == program.difficulty }
            ?? workflowTemplates.first { $0.programCategory == .military }
            ?? createDefaultTemplate()
    }
    
    private func determineProgressionStrategy(for session: ActiveProgramSession) -> ProgressionStrategy {
        let recentPerformance = getRecentPerformance(for: session.id)
        
        if recentPerformance.consistency >= 0.9 && recentPerformance.averageEffort < 0.8 {
            return .aggressive
        } else if recentPerformance.consistency >= 0.7 {
            return .moderate
        } else {
            return .conservative
        }
    }
    
    private func getApplicableAdaptations(for session: ActiveProgramSession) -> [AdaptationRule] {
        return session.adaptations.map { adaptation in
            AdaptationRule(
                trigger: .performancePattern(adaptation.type),
                modification: .weightAdjustment(2.5),
                duration: .temporary(weeks: 2)
            )
        }
    }
    
    private func updateActiveWorkflows(for programs: [ActiveProgramSession]) {
        // Update active workflows based on program changes
        let activeSessionIds = Set(programs.map { $0.id })
        
        // Remove workflows for inactive programs
        activeWorkflows.removeAll { !activeSessionIds.contains($0.sessionId) }
        
        // Add workflows for new programs
        for program in programs {
            if !activeWorkflows.contains(where: { $0.sessionId == program.id }) {
                Task {
                    let workflow = await generateWorkflow(for: program)
                    let activeWorkflow = ActiveWorkflow(
                        id: UUID(),
                        sessionId: program.id,
                        generatedWorkflow: workflow,
                        currentWeek: program.userProgram.currentWeek,
                        lastRegeneration: Date(),
                        adaptationCount: 0
                    )
                    activeWorkflows.append(activeWorkflow)
                }
            }
        }
    }
    
    // MARK: - Template Creation Methods
    
    private func createMilitaryFoundationTemplate() -> WorkflowTemplate {
        return WorkflowTemplate(
            id: UUID(),
            name: "Military Foundation",
            programCategory: .military,
            difficulty: .beginner,
            durationWeeks: 8,
            weekPatterns: createMilitaryFoundationPatterns(),
            baseParameters: createMilitaryFoundationParameters(),
            progressionRules: createMilitaryFoundationProgression()
        )
    }
    
    private func createRangerChallengeTemplate() -> WorkflowTemplate {
        return WorkflowTemplate(
            id: UUID(),
            name: "Ranger Challenge",
            programCategory: .military,
            difficulty: .advanced,
            durationWeeks: 12,
            weekPatterns: createRangerChallengePatterns(),
            baseParameters: createRangerChallengeParameters(),
            progressionRules: createRangerChallengeProgression()
        )
    }
    
    private func createSelectionPrepTemplate() -> WorkflowTemplate {
        return WorkflowTemplate(
            id: UUID(),
            name: "Selection Prep",
            programCategory: .military,
            difficulty: .elite,
            durationWeeks: 16,
            weekPatterns: createSelectionPrepPatterns(),
            baseParameters: createSelectionPrepParameters(),
            progressionRules: createSelectionPrepProgression()
        )
    }
    
    private func createMaintenanceTemplate() -> WorkflowTemplate {
        return WorkflowTemplate(
            id: UUID(),
            name: "Maintenance",
            programCategory: .fitness,
            difficulty: .intermediate,
            durationWeeks: 0, // Ongoing
            weekPatterns: createMaintenancePatterns(),
            baseParameters: createMaintenanceParameters(),
            progressionRules: createMaintenanceProgression()
        )
    }
    
    private func createDefaultTemplate() -> WorkflowTemplate {
        return WorkflowTemplate(
            id: UUID(),
            name: "Default",
            programCategory: .fitness,
            difficulty: .beginner,
            durationWeeks: 8,
            weekPatterns: createDefaultPatterns(),
            baseParameters: createDefaultParameters(),
            progressionRules: createDefaultProgression()
        )
    }
    
    // MARK: - Additional Helper Methods (to be implemented)
    
    private func calculateWorkoutParameters(
        session: ActiveProgramSession,
        week: Int,
        workoutType: WorkoutType,
        template: WorkflowTemplate
    ) async -> WorkoutParameters {
        // Implementation for calculating workout parameters
        return WorkoutParameters.default
    }
    
    private func generateWorkoutStructure(
        type: WorkoutType,
        parameters: WorkoutParameters,
        template: WorkflowTemplate
    ) -> WorkoutStructure {
        // Implementation for generating workout structure
        return WorkoutStructure(
            warmup: WorkoutSegment.default,
            mainSegments: [],
            cooldown: WorkoutSegment.default,
            totalEstimatedTime: 3600
        )
    }
    
    private func personalizeWorkouts(
        plan: [PlannedWorkout],
        session: ActiveProgramSession
    ) async -> [PlannedWorkout] {
        // Implementation for personalizing workouts
        return plan
    }
    
    private func calculateWorkoutDate(
        startWeek: Date,
        weekOffset: Int,
        workoutDay: WeekDay
    ) -> Date {
        let calendar = Calendar.current
        let targetWeek = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startWeek) ?? startWeek
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: targetWeek)?.start ?? targetWeek
        return calendar.date(byAdding: .day, value: workoutDay.rawValue - 2, to: startOfWeek) ?? targetWeek
    }
    
    private func determineWorkoutType(
        dayIndex: Int,
        week: Int,
        phase: ProgramPhase,
        pattern: WeekPattern
    ) -> WorkoutType {
        guard dayIndex < pattern.workoutTypes.count else {
            return .endurance
        }
        return pattern.workoutTypes[dayIndex]
    }
    
    private func determinePhase(week: Int, totalWeeks: Int) -> ProgramPhase {
        let progress = Double(week) / Double(totalWeeks)
        
        switch progress {
        case 0..<0.25:
            return .foundation
        case 0.25..<0.75:
            return .building
        case 0.75..<0.9:
            return .peak
        default:
            return .taper
        }
    }
    
    private func calculateEstimatedDuration(structure: WorkoutStructure) -> TimeInterval {
        return structure.totalEstimatedTime
    }
    
    private func calculateWorkoutDifficulty(parameters: WorkoutParameters, type: WorkoutType) -> WorkoutDifficulty {
        let weightScore = parameters.targetWeight / 50.0
        let distanceScore = parameters.targetDistance / 5.0
        let intensityScore = parameters.intensityLevel
        
        let combinedScore = (weightScore + distanceScore + intensityScore) / 3.0
        
        switch combinedScore {
        case 0..<0.4:
            return .easy
        case 0.4..<0.7:
            return .moderate
        case 0.7..<0.9:
            return .hard
        default:
            return .extreme
        }
    }
    
    private func determinePrerequisites(week: Int, dayIndex: Int) -> [WorkoutPrerequisite] {
        var prerequisites: [WorkoutPrerequisite] = []
        
        if dayIndex > 0 {
            prerequisites.append(.restDay(hours: 24))
        }
        
        prerequisites.append(.equipment([.ruck]))
        
        if week > 4 {
            prerequisites.append(.healthCheck)
        }
        
        return prerequisites
    }
    
    private func getRecentPerformance(for sessionId: UUID) -> PerformanceMetrics {
        return PerformanceMetrics(
            consistency: 0.8,
            averageEffort: 0.7,
            progressTrend: 0.1
        )
    }
    
    private func cacheWorkflow(_ workflow: GeneratedWorkflow) async {
        let data = try? JSONEncoder().encode(workflow)
        UserDefaults.standard.set(data, forKey: "cached_workflow_\(workflow.sessionId.uuidString)")
    }
    
    private func loadAdaptationHistory() {
        if let data = UserDefaults.standard.data(forKey: "adaptation_history"),
           let history = try? JSONDecoder().decode([AdaptationRecord].self, from: data) {
            adaptationHistory = history
        }
    }
    
    // MARK: - Pattern Creation Methods (to be implemented)
    
    private func createMilitaryFoundationPatterns() -> [ProgramPhase: [WeekPattern]] {
        return [:]
    }
    
    private func createRangerChallengePatterns() -> [ProgramPhase: [WeekPattern]] {
        return [:]
    }
    
    private func createSelectionPrepPatterns() -> [ProgramPhase: [WeekPattern]] {
        return [:]
    }
    
    private func createMaintenancePatterns() -> [ProgramPhase: [WeekPattern]] {
        return [:]
    }
    
    private func createDefaultPatterns() -> [ProgramPhase: [WeekPattern]] {
        return [:]
    }
    
    // MARK: - Parameter Creation Methods (to be implemented)
    
    private func createMilitaryFoundationParameters() -> [WorkoutType: WorkoutParameters] {
        return [:]
    }
    
    private func createRangerChallengeParameters() -> [WorkoutType: WorkoutParameters] {
        return [:]
    }
    
    private func createSelectionPrepParameters() -> [WorkoutType: WorkoutParameters] {
        return [:]
    }
    
    private func createMaintenanceParameters() -> [WorkoutType: WorkoutParameters] {
        return [:]
    }
    
    private func createDefaultParameters() -> [WorkoutType: WorkoutParameters] {
        return [:]
    }
    
    // MARK: - Progression Rule Creation Methods (to be implemented)
    
    private func createMilitaryFoundationProgression() -> [TemplateProgressionRule] {
        return []
    }
    
    private func createRangerChallengeProgression() -> [TemplateProgressionRule] {
        return []
    }
    
    private func createSelectionPrepProgression() -> [TemplateProgressionRule] {
        return []
    }
    
    private func createMaintenanceProgression() -> [TemplateProgressionRule] {
        return []
    }
    
    private func createDefaultProgression() -> [TemplateProgressionRule] {
        return []
    }
}
