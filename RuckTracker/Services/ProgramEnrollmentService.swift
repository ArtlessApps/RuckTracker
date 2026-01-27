import Foundation

/// Owns program enrollment lifecycle and progress queries.
/// Backed by `LocalProgramStorage` (UserDefaults + CoreData derived info).
final class ProgramEnrollmentService {
    private let storage: LocalProgramStorage

    init(storage: LocalProgramStorage = .shared) {
        self.storage = storage
    }

    // MARK: - Enrollment

    func enroll(programId: UUID) {
        storage.enrollInProgram(programId)
    }

    func unenroll() {
        storage.unenrollFromProgram()
    }

    func enrolledProgramId() -> UUID? {
        storage.getEnrolledProgramId()
    }

    func enrollmentDate() -> Date? {
        storage.getEnrollmentDate()
    }

    // MARK: - User Programs

    func userPrograms() -> [UserProgram] {
        storage.getAllUserPrograms()
    }

    // MARK: - Progress

    func programProgress(programId: UUID) -> ProgramProgress {
        storage.getProgramProgress(programId: programId)
    }

    // MARK: - Completions

    func workoutCompletions(programId: UUID) -> [WorkoutCompletion] {
        // Get workouts from CoreData that belong to this program
        let programWorkouts = WorkoutDataManager.shared.workouts.filter { workout in
            workout.programId == programId.uuidString
        }

        // Convert to WorkoutCompletion models
        let completions = programWorkouts.compactMap { workout -> WorkoutCompletion? in
            guard let date = workout.date else { return nil }

            return WorkoutCompletion(
                id: UUID(),
                userId: UUID(), // Not needed for local
                userProgramId: programId,
                programWorkoutId: UUID(), // Match by day number instead
                completedAt: date,
                actualDistanceMiles: workout.distance,
                actualWeightLbs: workout.ruckWeight,
                actualDurationMinutes: Int(workout.duration / 60),
                performanceScore: nil,
                notes: nil
            )
        }

        return completions
    }
}


