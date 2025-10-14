import Foundation

class LocalWorkoutLoader {
    static let shared = LocalWorkoutLoader()
    
    private var cachedWorkouts: [ProgramWorkout] = []
    private var workoutsByWeekId: [UUID: [ProgramWorkout]] = [:]
    
    // Define all workout files to load
    private let workoutFiles = [
        "RuckReadyWorkouts",
        "FoundationBuilderWorkouts",
        "ActiveLifestyleWorkouts",
        "EnduranceBuildWorkouts",
        "GORUCKLightPrepWorkouts",
        "GORUCKHeavyToughPrepWorkouts",
        "ArmyACFTPrepWorkouts",
        "StrengthConditioningWorkouts",
        "MarathonRuckPrepWorkouts",
        "GORUCKSelectionPrepWorkouts"
    ]
    
    private init() {
        loadWorkouts()
    }
    
    // MARK: - Loading
    
    func loadWorkouts() {
        var allWorkouts: [ProgramWorkout] = []
        
        // Load each workout file
        for fileName in workoutFiles {
            let result: Result<[WorkoutJSON], Error> = Bundle.main.decodeWithCustomDecoder("\(fileName).json")
            
            switch result {
            case .success(let workoutsData):
                let programWorkouts = workoutsData.map { $0.toProgramWorkout() }
                allWorkouts.append(contentsOf: programWorkouts)
                print("✅ Loaded \(programWorkouts.count) workouts from \(fileName).json")
                
            case .failure(let error):
                print("⚠️ Failed to load \(fileName).json: \(error)")
                // Continue loading other files even if one fails
            }
        }
        
        cachedWorkouts = allWorkouts
        
        // Index by week_id for fast lookup
        workoutsByWeekId = Dictionary(grouping: cachedWorkouts) { $0.weekId }
        
        print("✅ Total workouts loaded: \(cachedWorkouts.count)")
    }
    
    // MARK: - Querying
    
    func getWorkouts(forWeekId weekId: UUID) -> [ProgramWorkout] {
        return workoutsByWeekId[weekId]?.sorted { $0.dayNumber < $1.dayNumber } ?? []
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
    let idx: Int?  // Optional index field (present in some JSONs like RuckReadyWorkouts)
    
    enum CodingKeys: String, CodingKey {
        case id
        case idx
        case dayNumber = "day_number"
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
        
        // Handle optional idx field (present in some workout files)
        idx = try container.decodeIfPresent(Int.self, forKey: .idx)
        
        // Handle distance_miles as string that needs to be converted to Double
        // Also handle case where it's already a Double
        if let distanceString = try? container.decode(String.self, forKey: .distanceMiles) {
            distanceMiles = Double(distanceString)
        } else if let distanceDouble = try? container.decode(Double.self, forKey: .distanceMiles) {
            distanceMiles = distanceDouble
        } else {
            distanceMiles = nil
        }
        
        // Handle target_pace_minutes as string that needs to be converted to Double
        // Also handle case where it's already a Double
        if let paceString = try? container.decode(String.self, forKey: .targetPaceMinutes) {
            targetPaceMinutes = Double(paceString)
        } else if let paceDouble = try? container.decode(Double.self, forKey: .targetPaceMinutes) {
            targetPaceMinutes = paceDouble
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

