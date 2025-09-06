import SwiftUI

struct PhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    Text("RuckTracker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your weighted walks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Current Session Info
                if workoutManager.isActive {
                    WorkoutStatsCard()
                } else {
                    // Quick Start Options
                    VStack(spacing: 15) {
                        WeightSelectorCard()
                        StartWorkoutButton()
                    }
                }
                
                Spacer()
                
                // History/Stats Preview
                RecentWorkoutsCard()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct WeightSelectorCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(.orange)
                Text("Ruck Weight")
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack {
                Button("-") {
                    if workoutManager.ruckWeight > 0 {
                        workoutManager.ruckWeight -= 5
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
                
                Spacer()
                
                Text("\(Int(workoutManager.ruckWeight)) lbs")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("+") {
                    workoutManager.ruckWeight += 5
                }
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct StartWorkoutButton: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        Button(action: {
            workoutManager.startWorkout()
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Rucking")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(15)
        }
    }
}

struct WorkoutStatsCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Active Workout")
                .font(.headline)
            
            HStack(spacing: 30) {
                VStack {
                    Text(workoutManager.formattedElapsedTime)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(String(format: "%.2f", workoutManager.distance))
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Miles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(Int(workoutManager.calories))")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                Button(workoutManager.isPaused ? "Resume" : "Pause") {
                    workoutManager.togglePause()
                }
                .foregroundColor(workoutManager.isPaused ? .green : .orange)
                
                Button("End Workout") {
                    workoutManager.endWorkout()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct RecentWorkoutsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Workouts")
                .font(.headline)
            
            // Placeholder for workout history
            Text("No recent workouts")
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

#Preview {
    PhoneMainView()
        .environmentObject(WorkoutManager())
}
