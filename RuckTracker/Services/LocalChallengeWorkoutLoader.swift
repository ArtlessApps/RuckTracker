// RuckTracker/Services/LocalChallengeWorkoutLoader.swift
import Foundation

class LocalChallengeWorkoutLoader {
    static let shared = LocalChallengeWorkoutLoader()
    
    private var cachedWorkouts: [ChallengeWorkout] = []
    private var workoutsByChallengeId: [UUID: [ChallengeWorkout]] = [:]
    
    private init() {
        loadWorkouts()
    }
    
    // MARK: - Loading
    
    func loadWorkouts() {
        let result: Result<[ChallengeWorkoutJSON], Error> = Bundle.main.decodeWithCustomDecoder("ChallengeWorkouts.json")
        
        switch result {
        case .success(let workoutsData):
            // Convert JSON to ChallengeWorkout models
            cachedWorkouts = workoutsData.map { $0.toChallengeWorkout() }
            
            // Index by challenge_id for fast lookup
            workoutsByChallengeId = Dictionary(grouping: cachedWorkouts) { $0.challengeId }
            
            print("✅ Loaded \(cachedWorkouts.count) challenge workouts from bundle")
            
        case .failure(let error):
            print("❌ Failed to load challenge workouts: \(error)")
            cachedWorkouts = []
            workoutsByChallengeId = [:]
        }
    }
    
    // MARK: - Querying
    
    func getWorkouts(forChallengeId challengeId: UUID) -> [ChallengeWorkout] {
        return workoutsByChallengeId[challengeId]?.sorted { $0.dayNumber < $1.dayNumber } ?? []
    }
    
    func getWorkout(byId workoutId: UUID) -> ChallengeWorkout? {
        return cachedWorkouts.first { $0.id == workoutId }
    }
}

// MARK: - JSON Decoding Model

private struct ChallengeWorkoutJSON: Codable {
    let idx: Int
    let id: String
    let challengeId: String
    let dayNumber: Int
    let workoutType: String
    let distanceMiles: Double?
    let targetPaceMinutes: Double?
    let weightLbs: Double?
    let durationMinutes: Int?
    let instructions: String?
    let isRestDay: Bool
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case idx, id
        case challengeId = "challenge_id"
        case dayNumber = "day_number"
        case workoutType = "workout_type"
        case distanceMiles = "distance_miles"
        case targetPaceMinutes = "target_pace_minutes"
        case weightLbs = "weight_lbs"
        case durationMinutes = "duration_minutes"
        case instructions
        case isRestDay = "is_rest_day"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom initializer to handle string-to-Double conversions
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idx = try container.decode(Int.self, forKey: .idx)
        id = try container.decode(String.self, forKey: .id)
        challengeId = try container.decode(String.self, forKey: .challengeId)
        dayNumber = try container.decode(Int.self, forKey: .dayNumber)
        workoutType = try container.decode(String.self, forKey: .workoutType)
        
        // Handle distance_miles as string -> Double
        if let distanceString = try container.decodeIfPresent(String.self, forKey: .distanceMiles) {
            distanceMiles = Double(distanceString)
        } else {
            distanceMiles = nil
        }
        
        // Handle target_pace_minutes as string -> Double
        if let paceString = try container.decodeIfPresent(String.self, forKey: .targetPaceMinutes) {
            targetPaceMinutes = Double(paceString)
        } else {
            targetPaceMinutes = nil
        }
        
        // Handle weight_lbs as string -> Double
        if let weightString = try container.decodeIfPresent(String.self, forKey: .weightLbs) {
            weightLbs = Double(weightString)
        } else {
            weightLbs = nil
        }
        
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        isRestDay = try container.decode(Bool.self, forKey: .isRestDay)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
    
    func toChallengeWorkout() -> ChallengeWorkout {
        return ChallengeWorkout(
            id: UUID(uuidString: id) ?? UUID(),
            challengeId: UUID(uuidString: challengeId) ?? UUID(),
            dayNumber: dayNumber,
            workoutType: ChallengeWorkout.WorkoutType(rawValue: workoutType) ?? .ruck,
            distanceMiles: distanceMiles,
            targetPaceMinutes: targetPaceMinutes,
            weightLbs: weightLbs,
            durationMinutes: durationMinutes,
            instructions: instructions,
            isRestDay: isRestDay,
            createdAt: parseDate(createdAt),
            updatedAt: parseDate(updatedAt)
        )
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS+00"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.date(from: dateString) ?? Date()
    }
}
