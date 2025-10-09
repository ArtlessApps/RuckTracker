import Foundation
import Combine

@MainActor
class LocalProgramService: ObservableObject {
    static let shared = LocalProgramService()
    
    // Published state
    @Published var programs: [Program] = []
    @Published var enrolledProgram: Program?
    @Published var programProgress: ProgramProgress?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storage = LocalProgramStorage.shared
    private var localPrograms: [LocalProgram] = []
    
    private init() {
        loadPrograms()
        loadEnrollmentStatus()
    }
    
    // MARK: - Program Loading
    
    func loadPrograms() {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load from bundled JSON
            let result: Result<[LocalProgram], Error> = Bundle.main.decodeWithErrorHandling("Programs.json")
            
            switch result {
            case .success(let loadedPrograms):
                localPrograms = loadedPrograms
                programs = loadedPrograms.map { $0.toProgram() }
                print("✅ Loaded \(programs.count) programs from bundle")
                
            case .failure(let error):
                errorMessage = "Failed to load programs: \(error.localizedDescription)"
                print("❌ Error loading programs: \(error)")
                // Fallback to mock data
                programs = Program.mockPrograms
            }
        }
        
        isLoading = false
    }
    
    func loadEnrollmentStatus() {
        guard let programId = storage.getEnrolledProgramId() else {
            enrolledProgram = nil
            programProgress = nil
            return
        }
        
        // Find the enrolled program
        enrolledProgram = programs.first { $0.id == programId }
        
        // Calculate progress
        if enrolledProgram != nil {
            programProgress = storage.getProgramProgress(programId: programId)
        }
        
        print("✅ Loaded enrollment status: \(enrolledProgram?.title ?? "None")")
    }
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ program: Program, startingWeight: Double) {
        storage.enrollInProgram(program.id, startingWeight: startingWeight)
        enrolledProgram = program
        programProgress = storage.getProgramProgress(programId: program.id)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Enrolled in program: \(program.title)")
    }
    
    func unenrollFromProgram() {
        storage.unenrollFromProgram()
        enrolledProgram = nil
        programProgress = nil
        
        print("✅ Unenrolled from current program")
    }
    
    // MARK: - Workout Loading
    
    func loadProgramWorkouts(programId: UUID) -> [ProgramWorkout] {
        // Find program in local data
        guard let localProgram = localPrograms.first(where: { $0.id == programId }) else {
            print("❌ Program not found: \(programId)")
            return []
        }
        
        // Convert all weeks and workouts to ProgramWorkout models
        var allWorkouts: [ProgramWorkout] = []
        
        for week in localProgram.weeks {
            let weekId = UUID() // Generate week ID
            let workouts = week.workouts.map { $0.toProgramWorkout(weekId: weekId) }
            allWorkouts.append(contentsOf: workouts)
        }
        
        print("✅ Loaded \(allWorkouts.count) workouts for program")
        return allWorkouts
    }
    
    func loadWorkoutCompletions(userProgramId: UUID) -> [WorkoutCompletion] {
        // Get workouts from CoreData that belong to this program
        let programWorkouts = WorkoutDataManager.shared.workouts.filter { workout in
            workout.programId == userProgramId.uuidString
        }
        
        // Convert to WorkoutCompletion models
        let completions = programWorkouts.compactMap { workout -> WorkoutCompletion? in
            guard let date = workout.date else { return nil }
            
            return WorkoutCompletion(
                id: UUID(),
                userId: UUID(), // Not needed for local
                userProgramId: userProgramId,
                programWorkoutId: UUID(), // Match by day number instead
                completedAt: date,
                actualDistanceMiles: workout.distance,
                actualWeightLbs: workout.ruckWeight,
                actualDurationMinutes: Int(workout.duration / 60),
                performanceScore: nil,
                notes: nil
            )
        }
        
        print("✅ Loaded \(completions.count) workout completions")
        return completions
    }
    
    // MARK: - Workout Completion
    
    func completeWorkout(
        programId: UUID,
        workoutDay: Int,
        distanceMiles: Double,
        weightLbs: Double,
        durationMinutes: Int
    ) {
        // Workout is already saved to CoreData by WorkoutManager
        // Just need to link it to the program
        
        // Update the most recent workout with program metadata
        if let recentWorkout = WorkoutDataManager.shared.workouts.first {
            recentWorkout.programId = programId.uuidString
            recentWorkout.programWorkoutDay = Int16(workoutDay)
            WorkoutDataManager.shared.saveContext()
        }
        
        // Recalculate progress
        programProgress = storage.getProgramProgress(programId: programId)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Completed workout day \(workoutDay) for program")
    }
    
    // MARK: - Helper Methods
    
    func isEnrolledIn(programId: UUID) -> Bool {
        return storage.getEnrolledProgramId() == programId
    }
    
    func getEnrolledProgramId() -> UUID? {
        return storage.getEnrolledProgramId()
    }
}
