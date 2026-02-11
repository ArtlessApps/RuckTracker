import Foundation

/// Canonical MARCH session taxonomy and metadata used to assemble personalized plans.
enum MarchSessionType: String, CaseIterable {
    case recoveryRuck = "Recovery Ruck"
    case pacePusher = "Pace Pusher Ruck"
    case verticalGrind = "Vertical Grind Ruck"
    case loadTest = "Load Test Ruck"
    case endurance = "Endurance Ruck"
    case integratedPT = "Integrated PT Ruck"
    case standardTest = "Standard Test Ruck"
}

struct MarchSessionDescriptor {
    let type: MarchSessionType
    let purpose: String
    /// ⚠️ FUTURE FEATURE: These hooks describe planned premium audio/coaching prompts
    /// that are NOT yet implemented. See docs/FUTURE_FEATURES.md.
    let premiumHook: String
    let defaultDistanceMiles: Double
    let targetPaceMinutes: Double?
    
    static func catalog() -> [MarchSessionType: MarchSessionDescriptor] {
        return [
            .recoveryRuck: MarchSessionDescriptor(
                type: .recoveryRuck,
                purpose: "Low-weight, Zone 2 maintenance. Focus on gait and joint health.",
                premiumHook: "Audio coach guides HR zones.",
                defaultDistanceMiles: 2.0,
                targetPaceMinutes: nil
            ),
            .pacePusher: MarchSessionDescriptor(
                type: .pacePusher,
                purpose: "Alternate 15-min/mile efforts with recovery pace.",
                premiumHook: "Audio coach calls GO / RECOVER by pace and time.",
                defaultDistanceMiles: 3.0,
                targetPaceMinutes: 15.0
            ),
            .verticalGrind: MarchSessionDescriptor(
                type: .verticalGrind,
                purpose: "Prioritize elevation over speed; keep HR high on the ascent.",
                premiumHook: "GPS vertical feet tracked; audio prompts on grade.",
                defaultDistanceMiles: 3.0,
                targetPaceMinutes: nil
            ),
            .loadTest: MarchSessionDescriptor(
                type: .loadTest,
                purpose: "Max-effort sustained pace with heavier weight.",
                premiumHook: "Weight over time tracked for strength progression.",
                defaultDistanceMiles: 4.0,
                targetPaceMinutes: 15.5
            ),
            .endurance: MarchSessionDescriptor(
                type: .endurance,
                purpose: "High distance, low intensity; gear and hydration check.",
                premiumHook: "Audio gear/hydration prompts.",
                defaultDistanceMiles: 6.0,
                targetPaceMinutes: nil
            ),
            .integratedPT: MarchSessionDescriptor(
                type: .integratedPT,
                purpose: "Short ruck with 3-5 PT stops (ruck on).",
                premiumHook: "Rep/set tracking with audio countdowns.",
                defaultDistanceMiles: 2.5,
                targetPaceMinutes: nil
            ),
            .standardTest: MarchSessionDescriptor(
                type: .standardTest,
                purpose: "Benchmark (e.g., 12 miles in 3 hours).",
                premiumHook: "Pace consistency and drop-off analysis.",
                defaultDistanceMiles: 8.0,
                targetPaceMinutes: 15.0
            )
        ]
    }
}

/// Lightweight generator that assembles a LocalProgram + weeks + workouts from MARCH sessions.
enum MarchPlanGenerator {
    static let programId = UUID(uuidString: "aaaa1111-2222-3333-4444-555555555555")!
    static let programTitle = "MARCH Personalized Plan"
    
    struct GeneratedPlan {
        let program: LocalProgram
        let weeks: [LocalProgramWeek]
    }
    
    static func generatePlan(for settings: UserSettings) -> GeneratedPlan {
        let catalog = MarchSessionDescriptor.catalog()
        
        // Choose progression length and pattern based on goal.
        let (durationWeeks, weeklyPattern): (Int, [[MarchSessionType]]) = {
            switch settings.ruckingGoal {
            case .military:
                return (8, militaryPattern())
            case .hiking:
                return (6, hikingPattern())
            case .goruckBasic, .goruckTough:
                return (8, eventPattern())
            case .weightLoss:
                return (6, generalFitnessPattern())
            case .longevity:
                return (6, generalFitnessPattern())
            }
        }()
        
        let baseWeight = settings.defaultRuckWeight
        let baselinePace = settings.baselinePaceMinutesPerMile
        
        var weeks: [LocalProgramWeek] = []
        for weekNumber in 1...durationWeeks {
            let sessionTypes = weekNumber <= weeklyPattern.count ? weeklyPattern[weekNumber - 1] : weeklyPattern.last ?? []
            let weekId = UUID()
            
            let workouts: [LocalProgramWorkout] = sessionTypes.enumerated().map { index, type in
                let descriptor = catalog[type]!
                let distance = progressiveDistance(for: descriptor, week: weekNumber)
                let targetPace = descriptor.targetPaceMinutes ?? baselinePace
                let weight = progressiveWeight(baseWeight: baseWeight, sessionType: type, week: weekNumber)
                
                return LocalProgramWorkout(
                    id: UUID(),
                    dayNumber: index + 1,
                    workoutType: descriptor.type.rawValue,
                    distanceMiles: distance,
                    targetPaceMinutes: targetPace,
                    instructions: sessionInstructions(descriptor: descriptor, weight: weight)
                )
            }
            
            let week = LocalProgramWeek(
                id: weekId,
                weekNumber: weekNumber,
                baseWeightLbs: progressiveWeight(baseWeight: baseWeight, sessionType: .recoveryRuck, week: weekNumber),
                description: "Week \(weekNumber): Personalized MARCH block",
                workouts: workouts
            )
            weeks.append(week)
        }
        
        let program = LocalProgram(
            id: programId,
            title: programTitle,
            description: "A structured, adaptive plan built from MARCH RUCK sessions.",
            difficulty: difficulty(for: settings),
            category: "fitness",
            durationWeeks: durationWeeks,
            isFeatured: true,
            isActive: true,
            sortOrder: 0,
            weeks: weeks
        )
        
        return GeneratedPlan(program: program, weeks: weeks)
    }
    
    // MARK: - Patterns
    
    private static func generalFitnessPattern() -> [[MarchSessionType]] {
        [
            [.recoveryRuck, .pacePusher, .endurance],
            [.recoveryRuck, .pacePusher, .verticalGrind, .endurance],
            [.pacePusher, .integratedPT, .endurance],
            [.recoveryRuck, .pacePusher, .endurance, .verticalGrind],
            [.pacePusher, .loadTest, .endurance],
            [.recoveryRuck, .standardTest, .endurance]
        ]
    }
    
    private static func militaryPattern() -> [[MarchSessionType]] {
        [
            [.pacePusher, .recoveryRuck, .integratedPT],
            [.pacePusher, .verticalGrind, .endurance],
            [.pacePusher, .loadTest, .integratedPT, .recoveryRuck],
            [.pacePusher, .endurance, .standardTest],
            [.pacePusher, .verticalGrind, .loadTest],
            [.pacePusher, .integratedPT, .endurance],
            [.pacePusher, .standardTest, .recoveryRuck],
            [.pacePusher, .loadTest, .standardTest]
        ]
    }
    
    private static func hikingPattern() -> [[MarchSessionType]] {
        [
            [.recoveryRuck, .verticalGrind, .endurance],
            [.verticalGrind, .pacePusher, .endurance],
            [.verticalGrind, .integratedPT, .endurance],
            [.verticalGrind, .endurance, .loadTest],
            [.pacePusher, .verticalGrind, .endurance],
            [.verticalGrind, .standardTest, .endurance]
        ]
    }
    
    private static func eventPattern() -> [[MarchSessionType]] {
        [
            [.recoveryRuck, .integratedPT, .endurance],
            [.pacePusher, .integratedPT, .endurance],
            [.pacePusher, .loadTest, .endurance],
            [.pacePusher, .integratedPT, .verticalGrind],
            [.pacePusher, .loadTest, .endurance],
            [.pacePusher, .integratedPT, .standardTest],
            [.pacePusher, .loadTest, .endurance],
            [.standardTest, .recoveryRuck, .endurance]
        ]
    }
    
    // MARK: - Helpers
    
    private static func difficulty(for settings: UserSettings) -> String {
        switch settings.experienceLevel {
        case .beginner: return "beginner"
        case .intermediate: return "intermediate"
        case .advanced: return "advanced"
        }
    }
    
    private static func progressiveDistance(for descriptor: MarchSessionDescriptor, week: Int) -> Double {
        let increment = week <= 2 ? 0.25 : 0.5
        return descriptor.defaultDistanceMiles + (Double(max(0, week - 1)) * increment)
    }
    
    private static func progressiveWeight(baseWeight: Double, sessionType: MarchSessionType, week: Int) -> Double {
        let addPerWeek = sessionType == .loadTest ? 5.0 : 2.0
        let capped = baseWeight + (Double(max(0, week - 1)) * addPerWeek)
        return min(capped, baseWeight + 20)
    }
    
    private static func sessionInstructions(descriptor: MarchSessionDescriptor, weight: Double) -> String {
        """
        \(descriptor.type.rawValue): \(descriptor.purpose)
        Premium: \(descriptor.premiumHook)
        Target weight: \(Int(weight)) lbs
        """
    }
}


