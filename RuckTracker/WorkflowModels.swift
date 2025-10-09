//
//  WorkflowModels.swift
//  RuckTracker
//
//  Supporting data models for ProgramWorkflowEngine
//

import Foundation

// MARK: - Missing Type Definitions

enum ProgramPhase: String, Codable, CaseIterable {
    case foundation = "Foundation"
    case build = "Build"
    case peak = "Peak"
    case taper = "Taper"
    case recovery = "Recovery"
}

enum WorkoutType: String, Codable, CaseIterable {
    case endurance = "Endurance"
    case strength = "Strength"
    case speed = "Speed"
    case recovery = "Recovery"
    case test = "Test"
}

enum Equipment: String, Codable, CaseIterable {
    case rucksack = "Rucksack"
    case weightPlates = "Weight Plates"
    case hydration = "Hydration"
    case boots = "Boots"
    case clothing = "Clothing"
    case gps = "GPS"
    case heartRateMonitor = "Heart Rate Monitor"
}

enum AdaptationType: String, Codable, CaseIterable {
    case performanceDecline = "Performance Decline"
    case consistencyIssues = "Consistency Issues"
    case injuryRisk = "Injury Risk"
    case overtraining = "Overtraining"
    case undertraining = "Undertraining"
}

// MARK: - Core Workflow Models

struct WorkflowTemplate: Codable {
    let id: UUID
    let name: String
    let programCategory: Program.Category
    let difficulty: Program.Difficulty
    let durationWeeks: Int
    let weekPatterns: [ProgramPhase: [WeekPattern]]
    let baseParameters: [WorkoutType: WorkoutParameters]
    let progressionRules: [TemplateProgressionRule]
    
    func getWeekPattern(for phase: ProgramPhase, week: Int) -> WeekPattern {
        let patterns = weekPatterns[phase] ?? []
        let patternIndex = (week - 1) % max(patterns.count, 1)
        return patterns.isEmpty ? WeekPattern.default : patterns[patternIndex]
    }
}

struct WeekPattern: Codable {
    let workoutTypes: [WorkoutType]
    let intensityModifier: Double
    
    static let `default` = WeekPattern(
        workoutTypes: [.endurance, .strength, .endurance],
        intensityModifier: 0.8
    )
}

struct TemplateProgressionRule: Codable {
    let weekRange: ClosedRange<Int>
    let weightProgression: Double
    let distanceProgression: Double
    let intensityProgression: Double
}

struct WorkflowGeneratedWorkflow: Codable {
    let id: UUID
    let sessionId: UUID
    let template: WorkflowTemplate
    let generatedDate: Date
    let workouts: [PlannedWorkout]
    let progressionStrategy: ProgressionStrategy
    let adaptationRules: [AdaptationRule]
    let validityPeriod: TimePeriod
}

struct ActiveWorkflow: Codable {
    let id: UUID
    let sessionId: UUID
    let generatedWorkflow: WorkflowGeneratedWorkflow
    var currentWeek: Int
    var lastRegeneration: Date
    var adaptationCount: Int
}

struct PlannedWorkout: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let week: Int
    let dayIndex: Int
    let scheduledDate: Date
    let type: WorkoutType
    let phase: ProgramPhase
    let parameters: WorkoutParameters
    let structure: WorkoutStructure
    let estimatedDuration: TimeInterval
    let difficulty: WorkoutDifficulty
    let prerequisites: [WorkoutPrerequisite]
    var adaptationFlags: [AdaptationFlag]
}

struct WorkoutParameters: Codable {
    let targetWeight: Double
    let targetDistance: Double
    let targetPace: Double
    let intensityLevel: Double
    let restIntervals: TimeInterval
    let warmupDuration: SegmentDuration
    let cooldownDuration: SegmentDuration
    let maxHeartRate: Double
    let targetHeartRateZone: HeartRateZone
    
    static let `default` = WorkoutParameters(
        targetWeight: 25.0,
        targetDistance: 3.0,
        targetPace: 15.0,
        intensityLevel: 0.7,
        restIntervals: 60,
        warmupDuration: .time(600),
        cooldownDuration: .time(600),
        maxHeartRate: 180,
        targetHeartRateZone: .aerobic
    )
}

struct WorkoutStructure: Codable {
    let warmup: WorkoutSegment
    let mainSegments: [WorkoutSegment]
    let cooldown: WorkoutSegment
    let totalEstimatedTime: TimeInterval
}

struct WorkoutSegment: Identifiable, Codable {
    let id: UUID
    let type: SegmentType
    let duration: SegmentDuration
    var intensity: Double
    var instructions: String
    let targetMetrics: WorkoutTargetMetrics
    
    static let `default` = WorkoutSegment(
        id: UUID(),
        type: .steady,
        duration: .time(1800),
        intensity: 0.7,
        instructions: "Steady pace workout",
        targetMetrics: WorkoutTargetMetrics(
            pace: 15.0,
            heartRate: .aerobic,
            weight: 25.0
        )
    )
}

struct WorkoutTargetMetrics: Codable {
    let pace: Double
    let heartRate: HeartRateZone
    let weight: Double
}

struct ProgressionRule: Codable {
    let condition: ProgressionCondition
    let action: ProgressionAction
    let priority: ProgressionPriority
}

struct AdaptationRule: Codable {
    let trigger: AdaptationTrigger
    let modification: AdaptationModification
    let duration: AdaptationDuration
}

struct AdaptationRecord: Codable {
    let sessionId: UUID
    let reason: RegenerationReason
    let timestamp: Date
    let previousPerformance: PerformanceMetrics
    let appliedChanges: [String]
}

struct PerformanceTrends: Codable {
    var consistentlyEarly: Bool = false
    var consistentlyLate: Bool = false
    var strongEndurance: Bool = false
    var poorEndurance: Bool = false
    var lowHeartRateEffort: Bool = false
    var highHeartRateStress: Bool = false
}

struct PerformanceMetrics: Codable {
    let consistency: Double
    let averageEffort: Double
    let progressTrend: Double
}

struct AlgorithmConfiguration: Codable {
    let adaptationThreshold: Double = 0.8
    let regenerationInterval: TimeInterval = 14 * 24 * 60 * 60 // 2 weeks
    let maxAdaptationsPerWeek: Int = 2
    let minimumConsistencyForProgression: Double = 0.7
}

// MARK: - Enums for Workflow Engine

enum ProgressionStrategy: String, Codable, CaseIterable {
    case conservative = "Conservative"
    case moderate = "Moderate"
    case aggressive = "Aggressive"
}

enum RegenerationReason: String, Codable, CaseIterable {
    case scheduledUpdate = "Scheduled Update"
    case performanceDecline = "Performance Decline"
    case consistencyIssues = "Consistency Issues"
    case userRequest = "User Request"
    case injuryRecovery = "Injury Recovery"
    case equipmentChange = "Equipment Change"
}

enum SegmentType: String, Codable, CaseIterable {
    case warmup = "Warmup"
    case steady = "Steady"
    case interval = "Interval"
    case rest = "Rest"
    case buildup = "Buildup"
    case tempo = "Tempo"
    case recovery = "Recovery"
    case test = "Test"
    case cooldown = "Cooldown"
}

enum SegmentDuration: Codable {
    case time(TimeInterval)
    case distance(Double)
    
    var timeValue: TimeInterval {
        switch self {
        case .time(let interval):
            return interval
        case .distance(let miles):
            // Estimate time based on 15 min/mile pace
            return miles * 15 * 60
        }
    }
}

enum WorkoutDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case hard = "Hard"
    case extreme = "Extreme"
}

enum WorkoutPrerequisite: Codable {
    case restDay(hours: Int)
    case equipment([Equipment])
    case healthCheck
    case weatherCheck
    case previousWorkoutCompletion
    
    enum CodingKeys: String, CodingKey {
        case type, hours, equipment
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "restDay":
            let hours = try container.decode(Int.self, forKey: .hours)
            self = .restDay(hours: hours)
        case "equipment":
            let equipment = try container.decode([Equipment].self, forKey: .equipment)
            self = .equipment(equipment)
        case "healthCheck":
            self = .healthCheck
        case "weatherCheck":
            self = .weatherCheck
        case "previousWorkoutCompletion":
            self = .previousWorkoutCompletion
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid WorkoutPrerequisite type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .restDay(let hours):
            try container.encode("restDay", forKey: .type)
            try container.encode(hours, forKey: .hours)
        case .equipment(let equipment):
            try container.encode("equipment", forKey: .type)
            try container.encode(equipment, forKey: .equipment)
        case .healthCheck:
            try container.encode("healthCheck", forKey: .type)
        case .weatherCheck:
            try container.encode("weatherCheck", forKey: .type)
        case .previousWorkoutCompletion:
            try container.encode("previousWorkoutCompletion", forKey: .type)
        }
    }
    
    var description: String {
        switch self {
        case .restDay(let hours):
            return "Ensure \(hours) hours rest since last workout"
        case .equipment(let items):
            return "Required equipment: \(items.map { $0.rawValue }.joined(separator: ", "))"
        case .healthCheck:
            return "Perform health and injury check before starting"
        case .weatherCheck:
            return "Check weather conditions and adjust accordingly"
        case .previousWorkoutCompletion:
            return "Complete previous workout before proceeding"
        }
    }
}

enum AdaptationFlag: String, Codable, CaseIterable {
    case weightIncreased = "Weight Increased"
    case weightDecreased = "Weight Decreased"
    case distanceModified = "Distance Modified"
    case intensityAdjusted = "Intensity Adjusted"
    case scheduleModified = "Schedule Modified"
    case injuryConsideration = "Injury Consideration"
}

enum ProgressionCondition: Codable {
    case weeklyConsistency(threshold: Double)
    case averageCompletionTime(ratio: Double)
    case heartRateRecovery(threshold: Double)
    case missedWorkouts(count: Int)
    case userFeedback(rating: Int)
    
    enum CodingKeys: String, CodingKey {
        case type, threshold, ratio, count, rating
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "weeklyConsistency":
            let threshold = try container.decode(Double.self, forKey: .threshold)
            self = .weeklyConsistency(threshold: threshold)
        case "averageCompletionTime":
            let ratio = try container.decode(Double.self, forKey: .ratio)
            self = .averageCompletionTime(ratio: ratio)
        case "heartRateRecovery":
            let threshold = try container.decode(Double.self, forKey: .threshold)
            self = .heartRateRecovery(threshold: threshold)
        case "missedWorkouts":
            let count = try container.decode(Int.self, forKey: .count)
            self = .missedWorkouts(count: count)
        case "userFeedback":
            let rating = try container.decode(Int.self, forKey: .rating)
            self = .userFeedback(rating: rating)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid ProgressionCondition type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .weeklyConsistency(let threshold):
            try container.encode("weeklyConsistency", forKey: .type)
            try container.encode(threshold, forKey: .threshold)
        case .averageCompletionTime(let ratio):
            try container.encode("averageCompletionTime", forKey: .type)
            try container.encode(ratio, forKey: .ratio)
        case .heartRateRecovery(let threshold):
            try container.encode("heartRateRecovery", forKey: .type)
            try container.encode(threshold, forKey: .threshold)
        case .missedWorkouts(let count):
            try container.encode("missedWorkouts", forKey: .type)
            try container.encode(count, forKey: .count)
        case .userFeedback(let rating):
            try container.encode("userFeedback", forKey: .type)
            try container.encode(rating, forKey: .rating)
        }
    }
}

enum ProgressionAction: Codable {
    case increaseWeight(amount: Double)
    case decreaseWeight(amount: Double)
    case increaseDistance(multiplier: Double)
    case decreaseDistance(multiplier: Double)
    case increaseIntensity(multiplier: Double)
    case decreaseIntensity(multiplier: Double)
    case addRestDay
    case removeRestDay
    
    enum CodingKeys: String, CodingKey {
        case type, amount, multiplier
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "increaseWeight":
            let amount = try container.decode(Double.self, forKey: .amount)
            self = .increaseWeight(amount: amount)
        case "decreaseWeight":
            let amount = try container.decode(Double.self, forKey: .amount)
            self = .decreaseWeight(amount: amount)
        case "increaseDistance":
            let multiplier = try container.decode(Double.self, forKey: .multiplier)
            self = .increaseDistance(multiplier: multiplier)
        case "decreaseDistance":
            let multiplier = try container.decode(Double.self, forKey: .multiplier)
            self = .decreaseDistance(multiplier: multiplier)
        case "increaseIntensity":
            let multiplier = try container.decode(Double.self, forKey: .multiplier)
            self = .increaseIntensity(multiplier: multiplier)
        case "decreaseIntensity":
            let multiplier = try container.decode(Double.self, forKey: .multiplier)
            self = .decreaseIntensity(multiplier: multiplier)
        case "addRestDay":
            self = .addRestDay
        case "removeRestDay":
            self = .removeRestDay
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid ProgressionAction type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .increaseWeight(let amount):
            try container.encode("increaseWeight", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .decreaseWeight(let amount):
            try container.encode("decreaseWeight", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .increaseDistance(let multiplier):
            try container.encode("increaseDistance", forKey: .type)
            try container.encode(multiplier, forKey: .multiplier)
        case .decreaseDistance(let multiplier):
            try container.encode("decreaseDistance", forKey: .type)
            try container.encode(multiplier, forKey: .multiplier)
        case .increaseIntensity(let multiplier):
            try container.encode("increaseIntensity", forKey: .type)
            try container.encode(multiplier, forKey: .multiplier)
        case .decreaseIntensity(let multiplier):
            try container.encode("decreaseIntensity", forKey: .type)
            try container.encode(multiplier, forKey: .multiplier)
        case .addRestDay:
            try container.encode("addRestDay", forKey: .type)
        case .removeRestDay:
            try container.encode("removeRestDay", forKey: .type)
        }
    }
}

enum ProgressionPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

enum AdaptationTrigger: Codable {
    case performancePattern(AdaptationType)
    case consistencyThreshold(Double)
    case heartRateAnomaly
    case userFeedback
    case injuryRisk
    
    enum CodingKeys: String, CodingKey {
        case type, adaptationType, threshold
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "performancePattern":
            let adaptationType = try container.decode(AdaptationType.self, forKey: .adaptationType)
            self = .performancePattern(adaptationType)
        case "consistencyThreshold":
            let threshold = try container.decode(Double.self, forKey: .threshold)
            self = .consistencyThreshold(threshold)
        case "heartRateAnomaly":
            self = .heartRateAnomaly
        case "userFeedback":
            self = .userFeedback
        case "injuryRisk":
            self = .injuryRisk
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid AdaptationTrigger type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .performancePattern(let adaptationType):
            try container.encode("performancePattern", forKey: .type)
            try container.encode(adaptationType, forKey: .adaptationType)
        case .consistencyThreshold(let threshold):
            try container.encode("consistencyThreshold", forKey: .type)
            try container.encode(threshold, forKey: .threshold)
        case .heartRateAnomaly:
            try container.encode("heartRateAnomaly", forKey: .type)
        case .userFeedback:
            try container.encode("userFeedback", forKey: .type)
        case .injuryRisk:
            try container.encode("injuryRisk", forKey: .type)
        }
    }
}

enum AdaptationModification: Codable {
    case weightAdjustment(Double)
    case distanceAdjustment(Double)
    case intensityAdjustment(Double)
    case scheduleChange
    case workoutTypeChange(WorkoutType)
    
    enum CodingKeys: String, CodingKey {
        case type, adjustment, workoutType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "weightAdjustment":
            let adjustment = try container.decode(Double.self, forKey: .adjustment)
            self = .weightAdjustment(adjustment)
        case "distanceAdjustment":
            let adjustment = try container.decode(Double.self, forKey: .adjustment)
            self = .distanceAdjustment(adjustment)
        case "intensityAdjustment":
            let adjustment = try container.decode(Double.self, forKey: .adjustment)
            self = .intensityAdjustment(adjustment)
        case "scheduleChange":
            self = .scheduleChange
        case "workoutTypeChange":
            let workoutType = try container.decode(WorkoutType.self, forKey: .workoutType)
            self = .workoutTypeChange(workoutType)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid AdaptationModification type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .weightAdjustment(let adjustment):
            try container.encode("weightAdjustment", forKey: .type)
            try container.encode(adjustment, forKey: .adjustment)
        case .distanceAdjustment(let adjustment):
            try container.encode("distanceAdjustment", forKey: .type)
            try container.encode(adjustment, forKey: .adjustment)
        case .intensityAdjustment(let adjustment):
            try container.encode("intensityAdjustment", forKey: .type)
            try container.encode(adjustment, forKey: .adjustment)
        case .scheduleChange:
            try container.encode("scheduleChange", forKey: .type)
        case .workoutTypeChange(let workoutType):
            try container.encode("workoutTypeChange", forKey: .type)
            try container.encode(workoutType, forKey: .workoutType)
        }
    }
}

enum AdaptationDuration: Codable {
    case temporary(weeks: Int)
    case permanent
    case untilCondition(ProgressionCondition)
    
    enum CodingKeys: String, CodingKey {
        case type, weeks, condition
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "temporary":
            let weeks = try container.decode(Int.self, forKey: .weeks)
            self = .temporary(weeks: weeks)
        case "permanent":
            self = .permanent
        case "untilCondition":
            let condition = try container.decode(ProgressionCondition.self, forKey: .condition)
            self = .untilCondition(condition)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid AdaptationDuration type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .temporary(let weeks):
            try container.encode("temporary", forKey: .type)
            try container.encode(weeks, forKey: .weeks)
        case .permanent:
            try container.encode("permanent", forKey: .type)
        case .untilCondition(let condition):
            try container.encode("untilCondition", forKey: .type)
            try container.encode(condition, forKey: .condition)
        }
    }
}

enum TimePeriod: Codable {
    case days(Int)
    case weeks(Int)
    case months(Int)
    
    enum CodingKeys: String, CodingKey {
        case type, count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let count = try container.decode(Int.self, forKey: .count)
        
        switch type {
        case "days":
            self = .days(count)
        case "weeks":
            self = .weeks(count)
        case "months":
            self = .months(count)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid TimePeriod type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .days(let count):
            try container.encode("days", forKey: .type)
            try container.encode(count, forKey: .count)
        case .weeks(let count):
            try container.encode("weeks", forKey: .type)
            try container.encode(count, forKey: .count)
        case .months(let count):
            try container.encode("months", forKey: .type)
            try container.encode(count, forKey: .count)
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .days(let count):
            return TimeInterval(count * 24 * 60 * 60)
        case .weeks(let count):
            return TimeInterval(count * 7 * 24 * 60 * 60)
        case .months(let count):
            return TimeInterval(count * 30 * 24 * 60 * 60)
        }
    }
}

// MARK: - Workflow Engine Errors

enum WorkflowEngineError: Error {
    case sessionNotFound
    case templateNotFound
    case invalidParameters
    case generationFailed
    case adaptationFailed
    case cacheCorrupted
    
    var localizedDescription: String {
        switch self {
        case .sessionNotFound:
            return "Program session not found"
        case .templateNotFound:
            return "Workflow template not found"
        case .invalidParameters:
            return "Invalid workout parameters"
        case .generationFailed:
            return "Failed to generate workout plan"
        case .adaptationFailed:
            return "Failed to apply adaptations"
        case .cacheCorrupted:
            return "Workflow cache is corrupted"
        }
    }
}

// MARK: - Extensions for Enhanced Functionality

extension WorkflowTemplate {
    func getProgressionRule(for week: Int) -> TemplateProgressionRule? {
        return progressionRules.first { $0.weekRange.contains(week) }
    }
    
    func calculateProgressiveParameters(
        baseParams: WorkoutParameters,
        week: Int,
        workoutType: WorkoutType
    ) -> WorkoutParameters {
        guard let rule = getProgressionRule(for: week) else {
            return baseParams
        }
        
        let weekProgression = Double(week - 1)
        
        return WorkoutParameters(
            targetWeight: baseParams.targetWeight + (rule.weightProgression * weekProgression),
            targetDistance: baseParams.targetDistance + (rule.distanceProgression * weekProgression),
            targetPace: baseParams.targetPace,
            intensityLevel: min(baseParams.intensityLevel + (rule.intensityProgression * weekProgression), 1.2),
            restIntervals: baseParams.restIntervals,
            warmupDuration: baseParams.warmupDuration,
            cooldownDuration: baseParams.cooldownDuration,
            maxHeartRate: baseParams.maxHeartRate,
            targetHeartRateZone: baseParams.targetHeartRateZone
        )
    }
}

extension PlannedWorkout {
    var formattedInstructions: String {
        var instructions = """
        **\(type.rawValue) Workout - Week \(week), Day \(dayIndex)**
        
        **Target Parameters:**
        • Weight: \(Int(parameters.targetWeight)) lbs
        • Distance: \(String(format: "%.1f", parameters.targetDistance)) miles
        • Target Pace: \(String(format: "%.1f", parameters.targetPace)) min/mile
        • Intensity: \(Int(parameters.intensityLevel * 100))%
        
        **Workout Structure:**
        """
        
        // Add warmup
        instructions += "\n\n**Warmup** (\(Int(structure.warmup.duration.timeValue / 60)) min):\n\(structure.warmup.instructions)"
        
        // Add main segments
        for (index, segment) in structure.mainSegments.enumerated() {
            instructions += "\n\n**Segment \(index + 1)** (\(formatDuration(segment.duration))):\n\(segment.instructions)"
        }
        
        // Add cooldown
        instructions += "\n\n**Cooldown** (\(Int(structure.cooldown.duration.timeValue / 60)) min):\n\(structure.cooldown.instructions)"
        
        // Add prerequisites if any
        if !prerequisites.isEmpty {
            instructions += "\n\n**Prerequisites:**"
            for prerequisite in prerequisites {
                instructions += "\n• \(prerequisite.description)"
            }
        }
        
        // Add adaptation notes if any
        if !adaptationFlags.isEmpty {
            instructions += "\n\n**Adaptations Applied:**"
            for flag in adaptationFlags {
                instructions += "\n• \(flag.rawValue)"
            }
        }
        
        return instructions
    }
    
    private func formatDuration(_ duration: SegmentDuration) -> String {
        switch duration {
        case .time(let interval):
            return "\(Int(interval / 60)) min"
        case .distance(let miles):
            return "\(String(format: "%.1f", miles)) miles"
        }
    }
    
    var progressPercentage: Double {
        let totalWeeks = 16 // This could be pulled from program
        return Double(week) / Double(totalWeeks) * 100
    }
    
    var isCompleted: Bool {
        return adaptationFlags.contains(.weightIncreased) || 
               adaptationFlags.contains(.weightDecreased) ||
               Date() > scheduledDate.addingTimeInterval(24 * 60 * 60) // Day has passed
    }
}

extension WorkflowGeneratedWorkflow {
    var upcomingWorkouts: [PlannedWorkout] {
        let now = Date()
        return workouts.filter { $0.scheduledDate > now }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    var currentWeekWorkouts: [PlannedWorkout] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
        
        return workouts.filter { workout in
            workout.scheduledDate >= weekStart && workout.scheduledDate < weekEnd
        }
    }
    
    var nextWorkout: PlannedWorkout? {
        return upcomingWorkouts.first
    }
    
    func getWorkout(for date: Date) -> PlannedWorkout? {
        let calendar = Calendar.current
        return workouts.first { workout in
            calendar.isDate(workout.scheduledDate, inSameDayAs: date)
        }
    }
    
    var isExpired: Bool {
        return Date().timeIntervalSince(generatedDate) > validityPeriod.timeInterval
    }
    
    func needsRegeneration(basedOn performance: PerformanceMetrics) -> Bool {
        if isExpired { return true }
        
        // Check if performance indicates need for regeneration
        if performance.consistency < 0.6 { return true }
        if performance.progressTrend < -0.2 { return true } // Significant decline
        
        return false
    }
}
