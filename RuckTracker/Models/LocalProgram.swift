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
    let weeks: [LocalProgramWeek]
    
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
    var id: UUID { UUID() } // Generate on the fly
    let weekNumber: Int
    let workouts: [LocalProgramWorkout]
    
    // Convert to existing ProgramWeek model
    func toProgramWeek(programId: UUID) -> ProgramWeek {
        return ProgramWeek(
            id: UUID(),
            programId: programId,
            weekNumber: weekNumber,
            baseWeightLbs: nil,
            description: nil
        )
    }
}

struct LocalProgramWorkout: Codable, Identifiable {
    var id: UUID { UUID() } // Generate on the fly
    let dayNumber: Int
    let workoutType: String
    let distanceMiles: Double?
    let targetPaceMinutes: Double?
    let instructions: String?
    
    // Convert to existing ProgramWorkout model
    func toProgramWorkout(weekId: UUID) -> ProgramWorkout {
        return ProgramWorkout(
            id: UUID(),
            weekId: weekId,
            dayNumber: dayNumber,
            workoutType: ProgramWorkout.WorkoutType(rawValue: workoutType) ?? .ruck,
            distanceMiles: distanceMiles,
            targetPaceMinutes: targetPaceMinutes,
            instructions: instructions
        )
    }
}
