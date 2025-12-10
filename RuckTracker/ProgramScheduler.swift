import Foundation

struct ScheduledWorkout: Identifiable {
    let id = UUID()
    let date: Date
    let weekNumber: Int
    let title: String
    let description: String
    let workoutID: String?
    let dayNumber: Int?
    let workoutType: String
    var isCompleted: Bool = false
    var isLocked: Bool = false
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
            let daysFromStart = calendar.dateComponents([.day], from: startDate, to: currentDate).day ?? 0
            let computedWeek = (daysFromStart / 7) + 1
            
            // If today is a training day
            if preferredDays.contains(weekday) {
                var item = workoutQueue[queueIndex]
                
                // Skip rest days: pull next non-rest workout into this training day
                while item.workout.workoutType.lowercased() == "rest" {
                    queueIndex += 1
                    if queueIndex >= workoutQueue.count { break }
                    item = workoutQueue[queueIndex]
                }
                
                if queueIndex >= workoutQueue.count { break }
                
                let scheduled = ScheduledWorkout(
                    date: currentDate,
                    // Use the calendar-relative week so labels progress as time passes,
                    // even if the user trains fewer days than the template provides.
                    weekNumber: computedWeek,
                    title: "Week \(computedWeek) - \(item.workout.workoutType.capitalized)",
                    description: "Target: \(item.workout.distanceMiles ?? 0) miles",
                    workoutID: item.workout.id.uuidString,
                    dayNumber: item.workout.dayNumber,
                    workoutType: item.workout.workoutType,
                    isCompleted: false
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

