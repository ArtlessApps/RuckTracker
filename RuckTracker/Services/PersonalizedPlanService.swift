import Foundation

/// Owns personalized-plan persistence/rehydration (currently the generated MARCH plan).
/// Generation itself is handled by `MarchPlanGenerator`.
final class PersonalizedPlanService {
    private let storage: LocalProgramStorage

    init(storage: LocalProgramStorage = .shared) {
        self.storage = storage
    }

    /// Persist the generated weeks for later rehydration across app launches.
    func persistMarchPlan(_ plan: MarchPlanGenerator.GeneratedPlan) {
        storage.setGeneratedWeeks(programId: plan.program.id, weeks: plan.weeks)
    }

    /// Rehydrate a MARCH `LocalProgram` from persisted generated weeks, if present.
    func loadPersistedMarchProgram() -> LocalProgram? {
        let weeks = storage.getGeneratedWeeks(programId: MarchPlanGenerator.programId)
        guard !weeks.isEmpty else { return nil }

        return LocalProgram(
            id: MarchPlanGenerator.programId,
            title: MarchPlanGenerator.programTitle,
            description: "A structured, adaptive plan built from MARCH RUCK sessions.",
            difficulty: "intermediate",
            category: "fitness",
            durationWeeks: weeks.count,
            isFeatured: true,
            isActive: true,
            sortOrder: 0,
            weeks: weeks
        )
    }
}


