//
//  StackChallengeModels.swift
//  RuckTracker
//
//  Challenge models for structured fitness challenges
//

import Foundation

// MARK: - Stack Challenge Model
struct StackChallenge: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let focusArea: FocusArea
    let durationDays: Int
    let weightPercentage: Double?
    let paceTarget: Double?
    let distanceFocus: Bool
    let recoveryFocus: Bool
    let season: Season?
    let isActive: Bool
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    
    
    enum FocusArea: String, Codable, CaseIterable {
        case power, speed, distance, recovery
        case progressiveWeight = "progressive_weight"
        case speedDevelopment = "speed_development"
        case enduranceProgression = "endurance_progression"
        case tacticalMixed = "tactical_mixed"
        
        var displayName: String {
            switch self {
            case .power: return "Power"
            case .speed: return "Speed"
            case .distance: return "Distance"
            case .recovery: return "Recovery"
            case .progressiveWeight: return "Progressive Weight"
            case .speedDevelopment: return "Speed Development"
            case .enduranceProgression: return "Endurance Progression"
            case .tacticalMixed: return "Tactical Mixed"
            }
        }
        
        var iconName: String {
            switch self {
            case .power, .progressiveWeight: return "scalemass.fill"
            case .speed, .speedDevelopment: return "speedometer"
            case .distance, .enduranceProgression: return "location.fill"
            case .recovery: return "heart.fill"
            case .tacticalMixed: return "shield.fill"
            }
        }
        
        var color: String {
            switch self {
            case .power, .progressiveWeight: return "red"
            case .speed, .speedDevelopment: return "blue"
            case .distance, .enduranceProgression: return "green"
            case .recovery: return "orange"
            case .tacticalMixed: return "purple"
            }
        }
    }
    
    enum Season: String, Codable, CaseIterable {
        case spring, summer, fall, winter
        
        var displayName: String {
            self.rawValue.capitalized
        }
        
        var iconName: String {
            switch self {
            case .spring: return "leaf.fill"
            case .summer: return "sun.max.fill"
            case .fall: return "maple.leaf.fill"
            case .winter: return "snowflake"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case focusArea = "focus_area"
        case durationDays = "duration_days"
        case weightPercentage = "weight_percentage"
        case paceTarget = "pace_target"
        case distanceFocus = "distance_focus"
        case recoveryFocus = "recovery_focus"
        case season
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - User Challenge Enrollment
struct UserChallengeEnrollment: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let challengeId: UUID
    let enrolledAt: Date
    var currentWeightLbs: Double
    let targetWeightLbs: Double?
    var isActive: Bool
    let completedAt: Date?
    var completionPercentage: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case challengeId = "challenge_id"
        case enrolledAt = "enrolled_at"
        case currentWeightLbs = "current_weight_lbs"
        case targetWeightLbs = "target_weight_lbs"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case completionPercentage = "completion_percentage"
    }
}

// MARK: - Challenge Workout
struct ChallengeWorkout: Codable, Identifiable {
    let id: UUID
    let challengeId: UUID
    let dayNumber: Int
    let workoutType: WorkoutType
    let distanceMiles: Double?
    let targetPaceMinutes: Double?
    let weightLbs: Double?
    let durationMinutes: Int?
    let instructions: String?
    let isRestDay: Bool
    
    enum WorkoutType: String, Codable {
        case ruck, rest, crossTraining = "cross_training"
        
        var displayName: String {
            switch self {
            case .ruck: return "Ruck"
            case .rest: return "Rest"
            case .crossTraining: return "Cross Training"
            }
        }
        
        var iconName: String {
            switch self {
            case .ruck: return "figure.walk"
            case .rest: return "bed.double.fill"
            case .crossTraining: return "dumbbell.fill"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengeId = "challenge_id"
        case dayNumber = "day_number"
        case workoutType = "workout_type"
        case distanceMiles = "distance_miles"
        case targetPaceMinutes = "target_pace_minutes"
        case weightLbs = "weight_lbs"
        case durationMinutes = "duration_minutes"
        case instructions
        case isRestDay = "is_rest_day"
    }
}

// MARK: - Step 1: Add these extensions to your existing StackChallengeModels.swift file
// Add after the existing ChallengeWorkout struct definition

extension ChallengeWorkout {
    
    // MARK: - Dynamic Title Generation
    func getWorkoutTitle(for challenge: StackChallenge) -> String {
        if isRestDay {
            return "Rest Day"
        }
        
        switch challenge.focusArea {
        case .power:
            return "Power Session"
        case .speed:
            return "Speed Work"
        case .distance:
            return "Distance Build"
        case .recovery:
            return "Active Recovery"
        case .progressiveWeight:
            return "Load Progression"
        case .speedDevelopment:
            return "Pace Development"
        case .enduranceProgression:
            return "Endurance Build"
        case .tacticalMixed:
            return "Tactical Training"
        }
    }
    
    // MARK: - Dynamic Instructions Generation
    func getInstructions(for challenge: StackChallenge) -> String {
        if let customInstructions = instructions, !customInstructions.isEmpty {
            return customInstructions
        }
        
        if isRestDay {
            return "Active recovery day - light movement and preparation"
        }
        
        // Generate instructions based on challenge focus and workout parameters
        var instruction = ""
        
        switch challenge.focusArea {
        case .power, .progressiveWeight:
            instruction = "Focus on maintaining proper form with heavy weight. "
            if let distance = distanceMiles {
                instruction += "Complete \(String(format: "%.1f", distance)) miles at a steady, controlled pace."
            }
            
        case .speed, .speedDevelopment:
            instruction = "Push your pace while maintaining good form. "
            if let pace = targetPaceMinutes {
                let minutes = Int(pace)
                let seconds = Int((pace - Double(minutes)) * 60)
                instruction += "Target pace: \(minutes):\(String(format: "%02d", seconds))/mile."
            }
            
        case .distance, .enduranceProgression:
            instruction = "Build endurance with steady effort. "
            if let distance = distanceMiles {
                instruction += "Cover \(String(format: "%.1f", distance)) miles maintaining consistent pace."
            }
            
        case .recovery:
            instruction = "Light recovery session. Focus on movement quality over intensity."
            
        case .tacticalMixed:
            instruction = "Mixed tactical training. Combine strength and endurance elements."
        }
        
        if let weight = weightLbs {
            instruction += " Carry \(Int(weight)) lbs throughout the session."
        }
        
        return instruction
    }
    
    // MARK: - Color Coordination
    func getColor(for challenge: StackChallenge) -> String {
        return challenge.focusArea.color
    }
}

// MARK: - Mock Workout Generation for Testing
extension ChallengeWorkout {
    static func generateMockWorkouts(for challenge: StackChallenge) -> [ChallengeWorkout] {
        var workouts: [ChallengeWorkout] = []
        
        for day in 1...challenge.durationDays {
            let workout = generateMockWorkout(for: challenge, day: day)
            workouts.append(workout)
        }
        
        return workouts
    }
    
    private static func generateMockWorkout(for challenge: StackChallenge, day: Int) -> ChallengeWorkout {
        // Determine if this should be a rest day (every other day for testing)
        let isRestDay = (day % 2 == 0) && challenge.focusArea != .recovery
        
        if isRestDay {
            return ChallengeWorkout(
                id: UUID(),
                challengeId: challenge.id,
                dayNumber: day,
                workoutType: .rest,
                distanceMiles: nil,
                targetPaceMinutes: nil,
                weightLbs: nil,
                durationMinutes: 30,
                instructions: nil, // Will use dynamic generation
                isRestDay: true
            )
        }
        
        // Generate training workout based on challenge focus
        let distance = calculateMockDistance(challenge: challenge, day: day)
        let weight = calculateMockWeight(challenge: challenge, day: day)
        let pace = calculateMockPace(challenge: challenge)
        
        return ChallengeWorkout(
            id: UUID(),
            challengeId: challenge.id,
            dayNumber: day,
            workoutType: .ruck,
            distanceMiles: distance,
            targetPaceMinutes: pace,
            weightLbs: weight,
            durationMinutes: nil,
            instructions: nil, // Will use dynamic generation
            isRestDay: false
        )
    }
    
    private static func calculateMockDistance(challenge: StackChallenge, day: Int) -> Double? {
        switch challenge.focusArea {
        case .distance, .enduranceProgression:
            // Progressive distance increase
            return 2.0 + (Double(day - 1) * 0.5)
            
        case .power, .progressiveWeight:
            // Varied distances for power focus
            let distances = [3.0, 2.0, 4.0, 2.5, 5.0, 3.5, 4.5]
            return distances[(day - 1) % distances.count]
            
        case .speed, .speedDevelopment:
            // Consistent distances for speed work
            return 3.0
            
        case .recovery:
            // Light distances
            return 1.5 + (Double(day - 1) * 0.25)
            
        case .tacticalMixed:
            // Mixed distances
            let distances = [2.5, 3.0, 4.0, 2.0, 5.0, 3.5, 6.0]
            return distances[(day - 1) % distances.count]
        }
    }
    
    private static func calculateMockWeight(challenge: StackChallenge, day: Int) -> Double? {
        guard let basePercentage = challenge.weightPercentage else {
            // Default weights if no percentage specified
            switch challenge.focusArea {
            case .power, .progressiveWeight:
                return 45.0 + (Double(day - 1) * 2.0) // Progressive increase
            case .speed, .speedDevelopment:
                return 25.0 // Light for speed
            case .distance, .enduranceProgression:
                return 35.0 // Moderate for distance
            case .recovery:
                return 15.0 // Very light
            case .tacticalMixed:
                return 40.0 // Standard tactical weight
            }
        }
        
        // Calculate based on percentage (assuming 180lb user for mock)
        let mockUserWeight = 180.0
        let baseWeight = mockUserWeight * (basePercentage / 100)
        
        // Apply progression based on challenge focus
        switch challenge.focusArea {
        case .power, .progressiveWeight:
            // 5% increase per day
            return baseWeight * (1.0 + (Double(day - 1) * 0.05))
            
        case .distance, .enduranceProgression:
            // Lighter for distance
            return baseWeight * 0.8
            
        case .recovery:
            // Very light
            return baseWeight * 0.5
            
        default:
            return baseWeight
        }
    }
    
    private static func calculateMockPace(challenge: StackChallenge) -> Double? {
        guard let basePace = challenge.paceTarget else {
            // Default paces if none specified
            switch challenge.focusArea {
            case .speed, .speedDevelopment:
                return 16.0 // Fast pace
            case .power, .progressiveWeight:
                return 20.0 // Slower with heavy weight
            case .distance, .enduranceProgression:
                return 18.0 // Steady endurance pace
            case .recovery:
                return 22.0 // Easy recovery pace
            case .tacticalMixed:
                return 18.5 // Mixed pace
            }
        }
        
        return basePace
    }
}

// MARK: - User Challenge Completion
struct UserChallengeCompletion: Codable, Identifiable {
    let id: UUID
    let userEnrollmentId: UUID
    let challengeWorkoutId: UUID
    let completedAt: Date
    let actualDistanceMiles: Double?
    let actualDurationMinutes: Int?
    let actualWeightLbs: Double?
    let performanceScore: Double?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userEnrollmentId = "user_enrollment_id"
        case challengeWorkoutId = "challenge_workout_id"
        case completedAt = "completed_at"
        case actualDistanceMiles = "actual_distance_miles"
        case actualDurationMinutes = "actual_duration_minutes"
        case actualWeightLbs = "actual_weight_lbs"
        case performanceScore = "performance_score"
        case notes
    }
}

// MARK: - Mock Data for Testing
extension StackChallenge {
    static let mockWeeklyChallenges: [StackChallenge] = [
        StackChallenge(
            id: UUID(),
            title: "Power Week",
            description: "Heavy weight focus challenge - Build strength with increased load carrying",
            focusArea: .power,
            durationDays: 7,
            weightPercentage: 27.5,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            season: nil,
            isActive: true,
            sortOrder: 1,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Speed Week",
            description: "Pace improvement focus challenge - Push your limits with faster paces",
            focusArea: .speed,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: 18.0,
            distanceFocus: false,
            recoveryFocus: false,
            season: nil,
            isActive: true,
            sortOrder: 2,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Distance Week",
            description: "Endurance building focus challenge - Go the extra mile",
            focusArea: .distance,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: true,
            recoveryFocus: false,
            season: nil,
            isActive: true,
            sortOrder: 3,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Active Recovery",
            description: "Light recovery focus challenge - Maintain movement while recovering",
            focusArea: .recovery,
            durationDays: 7,
            weightPercentage: 15.0,
            paceTarget: 22.0,
            distanceFocus: false,
            recoveryFocus: true,
            season: nil,
            isActive: true,
            sortOrder: 4,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
    
    static let mockSeasonalChallenges: [StackChallenge] = [
        StackChallenge(
            id: UUID(),
            title: "Load Carrier",
            description: "Progressive weight mastery challenge - Master heavy carries through systematic progression",
            focusArea: .progressiveWeight,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            season: .fall,
            isActive: true,
            sortOrder: 5,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Pace Pusher",
            description: "Speed development challenge - Systematic pace improvements over time",
            focusArea: .speedDevelopment,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            season: .winter,
            isActive: true,
            sortOrder: 6,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Distance Master",
            description: "Endurance progression challenge - Build your distance capabilities",
            focusArea: .enduranceProgression,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: true,
            recoveryFocus: false,
            season: .spring,
            isActive: true,
            sortOrder: 7,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Tactical Ready",
            description: "Mixed operational skills challenge - Real-world application focus",
            focusArea: .tacticalMixed,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            season: .summer,
            isActive: true,
            sortOrder: 8,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}
