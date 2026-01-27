import Foundation

struct MarchFeedback: Codable {
    let rpe: Int
    let soreness: Bool
    let timestamp: Date
}

enum MarchAdaptationEngine {
    private static let feedbackKey = "march_latest_feedback"
    
    static func saveFeedback(_ feedback: MarchFeedback) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(feedback) {
            UserDefaults.standard.set(data, forKey: feedbackKey)
        }
    }
    
    static func latestFeedback() -> MarchFeedback? {
        guard let data = UserDefaults.standard.data(forKey: feedbackKey) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(MarchFeedback.self, from: data)
    }
    
    /// Light-touch adaptation: if RPE was high or soreness flagged, reduce upcoming distances 10% and relabel.
    static func adapt(schedule: [ScheduledWorkout]) -> [ScheduledWorkout] {
        guard let feedback = latestFeedback(),
              Calendar.current.dateComponents([.day], from: feedback.timestamp, to: Date()).day ?? 0 <= 7 else {
            return schedule
        }
        
        let shouldDeload = feedback.rpe >= 8 || feedback.soreness
        guard shouldDeload else { return schedule }
        
        return schedule.map { workout in
            let adjustedDescription: String
            
            if workout.workoutType.lowercased() != "rest",
               let milesString = workout.description.split(separator: " ").first,
               let miles = Double(milesString) {
                let adjusted = max(1.0, miles * 0.9)
                adjustedDescription = "Target: \(String(format: "%.1f", adjusted)) miles (deload)"
            } else {
                adjustedDescription = workout.description
            }
            
            var newWorkout = ScheduledWorkout(
                date: workout.date,
                weekNumber: workout.weekNumber,
                title: workout.title,
                description: adjustedDescription,
                workoutID: workout.workoutID,
                dayNumber: workout.dayNumber,
                workoutType: workout.workoutType,
                isCompleted: workout.isCompleted,
                isLocked: workout.isLocked
            )
            
            return newWorkout
        }
    }
}


