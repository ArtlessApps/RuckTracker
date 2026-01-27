import Foundation

class LocalWeekLoader {
    static let shared = LocalWeekLoader()
    
    private var cachedWeeks: [LocalProgramWeek] = []
    private var weeksByProgram: [UUID: [LocalProgramWeek]] = [:]
    
    private init() {
        loadWeeks()
    }
    
    private func loadWeeks() {
        guard let url = Bundle.main.url(forResource: "ProgramWeeks", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ Failed to load ProgramWeeks.json")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let weekDataArray = try decoder.decode([WeekJSON].self, from: data)
            
            // Group weeks by program_id
            let groupedByProgram = Dictionary(grouping: weekDataArray, by: { $0.programId })
            
            // Convert to LocalProgramWeek and cache
            for (programIdString, weeks) in groupedByProgram {
                guard let programId = UUID(uuidString: programIdString) else {
                    print("❌ Invalid program ID: \(programIdString)")
                    continue
                }
                
                let localWeeks = weeks.map { $0.toLocalProgramWeek() }
                    .sorted { $0.weekNumber < $1.weekNumber }
                weeksByProgram[programId] = localWeeks
                cachedWeeks.append(contentsOf: localWeeks)
            }
            
            print("✅ Loaded \(cachedWeeks.count) weeks for \(weeksByProgram.count) programs")
        } catch {
            print("❌ Error decoding weeks: \(error)")
        }
    }
    
    func getWeeks(forProgramId programId: UUID) -> [LocalProgramWeek] {
        return weeksByProgram[programId] ?? []
    }
    
    func getWeek(programId: UUID, weekNumber: Int) -> LocalProgramWeek? {
        return weeksByProgram[programId]?.first { $0.weekNumber == weekNumber }
    }
}

// JSON decoding model
private struct WeekJSON: Codable {
    let id: String
    let programId: String
    let weekNumber: Int
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id, description
        case programId = "program_id"
        case weekNumber = "week_number"
    }
    
    func toLocalProgramWeek() -> LocalProgramWeek {
        let weekId = UUID(uuidString: id) ?? UUID()
        
        // Create with empty workouts - will be loaded separately
        return LocalProgramWeek(
            id: weekId,
            weekNumber: weekNumber,
            description: description,
            workouts: []
        )
    }
}

// Add initializer to LocalProgramWeek if needed
extension LocalProgramWeek {
    init(id: UUID, weekNumber: Int, baseWeightLbs: Double?, description: String?, workouts: [LocalProgramWorkout]) {
        self.id = id
        self.weekNumber = weekNumber
        self.baseWeightLbs = baseWeightLbs
        self.description = description
        self.workouts = workouts
    }
    
    // Convenience initializer without base weight reference
    init(id: UUID, weekNumber: Int, description: String?, workouts: [LocalProgramWorkout]) {
        self.id = id
        self.weekNumber = weekNumber
        self.baseWeightLbs = nil
        self.description = description
        self.workouts = workouts
    }
}
