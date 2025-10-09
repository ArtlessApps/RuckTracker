import Foundation

class LocalWorkoutLoader {
    static let shared = LocalWorkoutLoader()
    
    private var cachedWorkouts: [ProgramWorkout] = []
    private var workoutsByWeekId: [UUID: [ProgramWorkout]] = [:]
    
    private init() {
        loadWorkouts()
    }
    
    // MARK: - Loading
    
    func loadWorkouts() {
        let result: Result<[WorkoutJSON], Error> = Bundle.main.decodeWithCustomDecoder("Workouts.json")
        
        switch result {
        case .success(let workoutsData):
            // Convert JSON to ProgramWorkout models
            cachedWorkouts = workoutsData.map { $0.toProgramWorkout() }
            
            // Index by week_id for fast lookup
            workoutsByWeekId = Dictionary(grouping: cachedWorkouts) { $0.weekId }
            
            print("✅ Loaded \(cachedWorkouts.count) workouts from bundle")
            
        case .failure(let error):
            print("❌ Failed to load workouts: \(error)")
            cachedWorkouts = []
            workoutsByWeekId = [:]
        }
    }
    
    // MARK: - Querying
    
    func getWorkouts(forWeekId weekId: UUID) -> [ProgramWorkout] {
        return workoutsByWeekId[weekId] ?? []
    }
    
    func getAllWorkouts(forProgramId programId: UUID, weeks: [LocalProgramWeek]) -> [ProgramWorkout] {
        var allWorkouts: [ProgramWorkout] = []
        
        for week in weeks {
            let weekWorkouts = getWorkouts(forWeekId: week.id)
            allWorkouts.append(contentsOf: weekWorkouts)
        }
        
        return allWorkouts.sorted { $0.dayNumber < $1.dayNumber }
    }
    
    func getWorkout(byId workoutId: UUID) -> ProgramWorkout? {
        return cachedWorkouts.first { $0.id == workoutId }
    }
}

// MARK: - JSON Decoding Model

private struct WorkoutJSON: Codable {
    let id: String
    let weekId: String
    let dayNumber: Int
    let workoutType: String
    let distanceMiles: Double?
    let targetPaceMinutes: Double?
    let instructions: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, dayNumber = "day_number"
        case weekId = "week_id"
        case workoutType = "workout_type"
        case distanceMiles = "distance_miles"
        case targetPaceMinutes = "target_pace_minutes"
        case instructions
        case createdAt = "created_at"
    }
    
    // Custom initializer to handle the JSON structure
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        weekId = try container.decode(String.self, forKey: .weekId)
        dayNumber = try container.decode(Int.self, forKey: .dayNumber)
        workoutType = try container.decode(String.self, forKey: .workoutType)
        
        // Handle distance_miles as string that needs to be converted to Double
        if let distanceString = try container.decodeIfPresent(String.self, forKey: .distanceMiles) {
            distanceMiles = Double(distanceString)
        } else {
            distanceMiles = nil
        }
        
        // Handle target_pace_minutes as string that needs to be converted to Double
        if let paceString = try container.decodeIfPresent(String.self, forKey: .targetPaceMinutes) {
            targetPaceMinutes = Double(paceString)
        } else {
            targetPaceMinutes = nil
        }
        
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
    
    func toProgramWorkout() -> ProgramWorkout {
        return ProgramWorkout(
            id: UUID(uuidString: id) ?? UUID(),
            weekId: UUID(uuidString: weekId) ?? UUID(),
            dayNumber: dayNumber,
            workoutType: ProgramWorkout.WorkoutType(rawValue: workoutType) ?? .ruck,
            distanceMiles: distanceMiles,
            targetPaceMinutes: targetPaceMinutes,
            instructions: instructions
        )
    }
}
