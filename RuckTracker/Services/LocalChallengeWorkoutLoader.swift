// RuckTracker/Services/LocalChallengeWorkoutLoader.swift
import Foundation

class LocalChallengeWorkoutLoader {
    static let shared = LocalChallengeWorkoutLoader()
    
    private var cachedWorkouts: [ChallengeWorkout] = []
    private var workoutsByChallengeId: [UUID: [ChallengeWorkout]] = [:]
    
    // Legacy challenge workout files to load (fallback)
    // Note: Legacy challenge files were consolidated into program workouts
    // as part of the Rule of 3 cleanup. Challenges now use playlist-based loading.
    private let challengeWorkoutFiles: [String] = []
    
    private let challengePlaylistFile = "RuckChallengePlaylists"
    
    private init() {
        loadWorkouts()
    }
    
    // MARK: - Loading
    
    func loadWorkouts() {
        // Prefer new unit-based playlists
        if let playlistWorkouts = loadPlaylistWorkouts() {
            cachedWorkouts = playlistWorkouts
            workoutsByChallengeId = Dictionary(grouping: cachedWorkouts) { $0.challengeId }
            print("✅ Loaded \(cachedWorkouts.count) challenge workouts from RuckUnit playlists")
            return
        }
        
        var allWorkouts: [ChallengeWorkout] = []
        
        // Legacy fallback
        for fileName in challengeWorkoutFiles {
            let result: Result<[ChallengeWorkoutJSON], Error> = Bundle.main.decodeWithCustomDecoder("\(fileName).json")
            
            switch result {
            case .success(let workoutsData):
                let challengeWorkouts = workoutsData.map { $0.toChallengeWorkout() }
                allWorkouts.append(contentsOf: challengeWorkouts)
                print("✅ Loaded \(challengeWorkouts.count) workouts from \(fileName).json")
                
            case .failure(let error):
                print("⚠️ Failed to load \(fileName).json: \(error)")
                // Continue loading other files even if one fails
            }
        }
        
        cachedWorkouts = allWorkouts
        
        // Index by challenge_id for fast lookup
        workoutsByChallengeId = Dictionary(grouping: cachedWorkouts) { $0.challengeId }
        
        print("✅ Total challenge workouts loaded (legacy): \(cachedWorkouts.count)")
    }
    
    // MARK: - Querying
    
    func getWorkouts(forChallengeId challengeId: UUID) -> [ChallengeWorkout] {
        return workoutsByChallengeId[challengeId]?.sorted { $0.dayNumber < $1.dayNumber } ?? []
    }
    
    func getWorkout(byId workoutId: UUID) -> ChallengeWorkout? {
        return cachedWorkouts.first { $0.id == workoutId }
    }
    
    // MARK: - Playlist loader (Ruck Units)
    private func loadPlaylistWorkouts() -> [ChallengeWorkout]? {
        guard let url = Bundle.main.url(forResource: challengePlaylistFile, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        do {
            let playlists = try JSONDecoder().decode([ChallengePlaylistJSON].self, from: data)
            let catalog = MarchSessionDescriptor.catalog()
            let now = Date()
            
            var workouts: [ChallengeWorkout] = []
            for playlist in playlists {
                let challengeId = UUID(uuidString: playlist.id) ?? UUID()
                for (index, unitName) in playlist.units.enumerated() {
                    guard let sessionType = MarchSessionType(rawValue: unitName),
                          let descriptor = catalog[sessionType] else { continue }
                    
                    let workout = ChallengeWorkout(
                        id: UUID(),
                        challengeId: challengeId,
                        dayNumber: index + 1,
                        workoutType: .ruck,
                        distanceMiles: descriptor.defaultDistanceMiles,
                        targetPaceMinutes: descriptor.targetPaceMinutes,
                        weightLbs: nil,
                        durationMinutes: nil,
                        instructions: descriptor.purpose,
                        isRestDay: false,
                        createdAt: now,
                        updatedAt: now
                    )
                    workouts.append(workout)
                }
            }
            
            return workouts
        } catch {
            print("⚠️ Failed to load \(challengePlaylistFile).json: \(error)")
            return nil
        }
    }
}

// MARK: - JSON Decoding Model (legacy fallback)

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

// MARK: - Playlist JSON
private struct ChallengePlaylistJSON: Codable {
    let id: String
    let units: [String]
}
