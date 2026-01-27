import Foundation

/// Loads and serves the "catalog" of available training programs.
/// - Static sources: playlist-based programs and bundled JSON ("Programs.json" + weeks/workouts).
/// - Also supports injecting locally-generated programs (e.g. MARCH plan) into the in-memory catalog.
final class ProgramCatalogService {
    private let workoutLoader: LocalWorkoutLoader
    private let playlistLoader: UnitPlaylistLoader
    private let weekLoader: LocalWeekLoader

    private(set) var localPrograms: [LocalProgram] = []

    init(
        workoutLoader: LocalWorkoutLoader = .shared,
        playlistLoader: UnitPlaylistLoader = .shared,
        weekLoader: LocalWeekLoader = .shared
    ) {
        self.workoutLoader = workoutLoader
        self.playlistLoader = playlistLoader
        self.weekLoader = weekLoader
    }

    /// Loads the catalog and returns the converted `Program` models for UI consumption.
    /// Also populates `localPrograms` for week/workout lookups.
    func loadCatalog() -> Result<[Program], Error> {
        // Prefer playlist-based programs (Ruck Units).
        let playlistPrograms = playlistLoader.loadPlaylists()
        if !playlistPrograms.isEmpty {
            localPrograms = playlistPrograms
            return .success(playlistPrograms.map { $0.toProgram() })
        }

        // Fallback to legacy program JSON + week/workout stitching.
        let result: Result<[LocalProgram], Error> = Bundle.main.decodeWithCustomDecoder("Programs.json")
        switch result {
        case .success(var loadedPrograms):
            for i in 0..<loadedPrograms.count {
                let weeks = weekLoader.getWeeks(forProgramId: loadedPrograms[i].id)

                // Stitch workouts into each week from the workout loader.
                var updatedWeeks: [LocalProgramWeek] = []
                updatedWeeks.reserveCapacity(weeks.count)

                for week in weeks {
                    let programWorkouts = workoutLoader.getWorkouts(forWeekId: week.id)

                    let localWorkouts = programWorkouts.map { programWorkout in
                        LocalProgramWorkout(
                            id: programWorkout.id,
                            dayNumber: programWorkout.dayNumber,
                            workoutType: programWorkout.workoutType.rawValue,
                            distanceMiles: programWorkout.distanceMiles,
                            targetPaceMinutes: programWorkout.targetPaceMinutes,
                            instructions: programWorkout.instructions
                        )
                    }

                    updatedWeeks.append(
                        LocalProgramWeek(
                            id: week.id,
                            weekNumber: week.weekNumber,
                            baseWeightLbs: week.baseWeightLbs,
                            description: week.description,
                            workouts: localWorkouts
                        )
                    )
                }

                loadedPrograms[i].weeks = updatedWeeks
            }

            localPrograms = loadedPrograms
            return .success(loadedPrograms.map { $0.toProgram() })

        case .failure(let error):
            localPrograms = []
            return .failure(error)
        }
    }

    func upsertProgram(_ localProgram: LocalProgram) {
        localPrograms.removeAll { $0.id == localProgram.id }
        localPrograms.append(localProgram)
    }

    func removeProgram(programId: UUID) {
        localPrograms.removeAll { $0.id == programId }
    }

    func program(for programId: UUID) -> Program? {
        return localPrograms.first(where: { $0.id == programId })?.toProgram()
    }

    func programWeeks(programId: UUID) -> [LocalProgramWeek] {
        return localPrograms.first(where: { $0.id == programId })?.weeks ?? []
    }

    func programTitle(programId: UUID) -> String? {
        return localPrograms.first(where: { $0.id == programId })?.title
    }

    func loadProgramWorkouts(programId: UUID) -> [ProgramWorkout] {
        guard let localProgram = localPrograms.first(where: { $0.id == programId }) else {
            print("❌ Program not found: \(programId)")
            return []
        }

        // If the program has workouts embedded in its weeks (playlist-based, generated plans,
        // or stitched legacy plans), prefer those.
        let hasEmbeddedWorkouts = localProgram.weeks.contains { !$0.workouts.isEmpty }
        if hasEmbeddedWorkouts {
            let workouts = localProgram.weeks.flatMap { week in
                week.workouts.map { workout in
                    ProgramWorkout(
                        id: workout.id,
                        weekId: week.id,
                        dayNumber: workout.dayNumber,
                        workoutType: ProgramWorkout.WorkoutType(rawValue: workout.workoutType) ?? .ruck,
                        distanceMiles: workout.distanceMiles,
                        targetPaceMinutes: workout.targetPaceMinutes,
                        instructions: workout.instructions
                    )
                }
            }
            return workouts.sorted { $0.dayNumber < $1.dayNumber }
        }

        // Fallback for legacy cases where workouts are only referenced via week_id.
        return workoutLoader.getAllWorkouts(forProgramId: programId, weeks: localProgram.weeks)
            .sorted { $0.dayNumber < $1.dayNumber }
    }
}


