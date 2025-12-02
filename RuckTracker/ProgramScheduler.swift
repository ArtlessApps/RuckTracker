import Foundation

struct ScheduledWorkout: Identifiable {
    let id = UUID()
    let date: Date
    let weekNumber: Int
    let title: String
    let description: String
    let workoutID: String?
}

class ProgramScheduler {
    static func generateSchedule(for programWeeks: [LocalProgramWeek], startDate: Date, preferredDays: [Int]) -> [ScheduledWorkout] {
        var schedule: [ScheduledWorkout] = []
        var currentDate = startDate
        var workoutQueue: [(week: Int, workout: LocalProgramWorkout)] = []
        
        // Flatten JSON
        for week in programWeeks {
            for workout in week.workouts {
                workoutQueue.append((week: week.weekNumber, workout: workout))
            }
        }
        
        // Map to User Calendar
        let calendar = Calendar.current
        var queueIndex = 0
        
        // Safety limit 100 days
        for _ in 0..<100 {
            if queueIndex >= workoutQueue.count { break }
            
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // If today is a training day
            if preferredDays.contains(weekday) {
                let item = workoutQueue[queueIndex]
                
                let scheduled = ScheduledWorkout(
                    date: currentDate,
                    weekNumber: item.week,
                    title: "Week \(item.week) - \(item.workout.workoutType.capitalized)",
                    description: "Target: \(item.workout.distanceMiles ?? 0) miles",
                    workoutID: item.workout.id.uuidString
                )
                
                schedule.append(scheduled)
                queueIndex += 1
            }
            
            // Next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return schedule
    }
}

