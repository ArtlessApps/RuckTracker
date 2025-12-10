import Foundation

/// Loader that treats Programs as playlists of Ruck Units.
/// Each playlist week lists unit names that map to MarchSessionType.
class UnitPlaylistLoader {
    static let shared = UnitPlaylistLoader()
    
    private init() {}
    
    func loadPlaylists() -> [LocalProgram] {
        guard let url = Bundle.main.url(forResource: "RuckUnitPlaylists", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ RuckUnitPlaylists.json not found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let playlists = try decoder.decode([PlaylistJSON].self, from: data)
            return playlists.map { $0.toLocalProgram() }
        } catch {
            print("❌ Failed to decode RuckUnitPlaylists.json: \(error)")
            return []
        }
    }
}

// MARK: - JSON models
private struct PlaylistJSON: Codable {
    let id: String
    let title: String
    let description: String
    let difficulty: String
    let category: String
    let durationWeeks: Int
    let isFeatured: Bool
    let isActive: Bool
    let sortOrder: Int
    let weeks: [PlaylistWeekJSON]
    
    func toLocalProgram() -> LocalProgram {
        let programId = UUID(uuidString: id) ?? UUID()
        let weeksConverted = weeks.map { $0.toLocalWeek(programId: programId) }
        
        return LocalProgram(
            id: programId,
            title: title,
            description: description,
            difficulty: difficulty,
            category: category,
            durationWeeks: durationWeeks,
            isFeatured: isFeatured,
            isActive: isActive,
            sortOrder: sortOrder,
            weeks: weeksConverted
        )
    }
}

private struct PlaylistWeekJSON: Codable {
    let weekNumber: Int
    let units: [String]
    
    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
        case units
    }
    
    func toLocalWeek(programId: UUID) -> LocalProgramWeek {
        let weekId = UUID()
        let workouts: [LocalProgramWorkout] = units.enumerated().map { index, unitName in
            let sessionType = MarchSessionType(rawValue: unitName) ?? .recoveryRuck
            let descriptor = MarchSessionDescriptor.catalog()[sessionType]!
            let distance = defaultDistance(for: descriptor, week: weekNumber)
            let targetPace = descriptor.targetPaceMinutes
            return LocalProgramWorkout(
                id: UUID(),
                dayNumber: index + 1,
                workoutType: descriptor.type.rawValue,
                distanceMiles: distance,
                targetPaceMinutes: targetPace,
                instructions: descriptor.purpose
            )
        }
        
        return LocalProgramWeek(
            id: weekId,
            weekNumber: weekNumber,
            baseWeightLbs: nil,
            description: "Week \(weekNumber)",
            workouts: workouts
        )
    }
    
    private func defaultDistance(for descriptor: MarchSessionDescriptor, week: Int) -> Double {
        let increment = week <= 2 ? 0.25 : 0.5
        return descriptor.defaultDistanceMiles + (Double(max(0, week - 1)) * increment)
    }
}

