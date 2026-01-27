import Foundation

// MARK: - Local Program Models (for JSON decoding)

struct LocalProgram: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let difficulty: String
    let category: String
    let durationWeeks: Int
    let isFeatured: Bool
    let isActive: Bool
    let sortOrder: Int
    var weeks: [LocalProgramWeek]  // CHANGE FROM 'let' TO 'var'
    
    // Convert to existing Program model
    func toProgram() -> Program {
        return Program(
            id: id,
            title: title,
            description: description,
            difficulty: Program.Difficulty(rawValue: difficulty) ?? .intermediate,
            category: Program.Category(rawValue: category) ?? .fitness,
            durationWeeks: durationWeeks,
            isFeatured: isFeatured,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

struct LocalProgramWeek: Codable, Identifiable {
    let id: UUID  // Change from computed to stored property
    let weekNumber: Int
    let baseWeightLbs: Double?      // ADD THIS
    let description: String?         // ADD THIS
    let workouts: [LocalProgramWorkout]
    
    // Coding keys for JSON decoding
    enum CodingKeys: String, CodingKey {
        case id = "week_id"  // Map to week_id from your JSON
        case weekNumber = "week_number"
        case baseWeightLbs = "base_weight_lbs"   // ADD THIS
        case description                          // ADD THIS
        case workouts
    }
    
    // Custom initializer to handle the week_id mapping
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let weekIdString = try container.decode(String.self, forKey: .id)
        id = UUID(uuidString: weekIdString) ?? UUID()
        weekNumber = try container.decode(Int.self, forKey: .weekNumber)
        baseWeightLbs = try container.decodeIfPresent(Double.self, forKey: .baseWeightLbs)  // ADD THIS
        description = try container.decodeIfPresent(String.self, forKey: .description)      // ADD THIS
        workouts = try container.decode([LocalProgramWorkout].self, forKey: .workouts)
    }
    
    // Convert to existing ProgramWeek model
    func toProgramWeek(programId: UUID) -> ProgramWeek {
        return ProgramWeek(
            id: id,  // Use actual ID instead of generating
            programId: programId,
            weekNumber: weekNumber,
            baseWeightLbs: baseWeightLbs,     // NOW MAPS CORRECTLY
            description: description           // NOW MAPS CORRECTLY
        )
    }
}

struct LocalProgramWorkout: Codable, Identifiable {
    let id: UUID  // Change from computed to stored property
    let dayNumber: Int
    let workoutType: String
    let distanceMiles: Double?
    let targetPaceMinutes: Double?
    let instructions: String?
    
    // Coding keys for JSON decoding
    enum CodingKeys: String, CodingKey {
        case id
        case dayNumber = "day_number"
        case workoutType = "workout_type"
        case distanceMiles = "distance_miles"
        case targetPaceMinutes = "target_pace_minutes"
        case instructions
    }
    
    // Convert to existing ProgramWorkout model
    func toProgramWorkout(weekId: UUID) -> ProgramWorkout {
        return ProgramWorkout(
            id: id,  // Use actual ID instead of generating
            weekId: weekId,
            dayNumber: dayNumber,
            workoutType: ProgramWorkout.WorkoutType(rawValue: workoutType) ?? .ruck,
            distanceMiles: distanceMiles,
            targetPaceMinutes: targetPaceMinutes,
            instructions: instructions
        )
    }
}
