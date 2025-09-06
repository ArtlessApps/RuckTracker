import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Top row: Weight, Heart Rate, Pace
            HStack {
                Text("\(Int(workoutManager.ruckWeight)) LBS")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(Int(workoutManager.heartRate))")
                        .foregroundColor(.red)
                }
                .font(.caption)
                
                Spacer()
                
                Text("PACE")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Center: Hiker and metrics
            VStack(spacing: 12) {
                HStack {
                    VStack {
                        Text("\(Int(workoutManager.calories))")
                            .font(.title3)
                            .foregroundColor(.white)
                        Text("CAL")
                            .font(.caption)
                            .foregroundColor(.gray)
                        if workoutManager.ruckWeight > 0 {
                            Text("LOADED")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Hiker icon
                    Image(systemName: "figure.hiking")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, isActive: workoutManager.isActive)
                    
                    Spacer()
                    
                    VStack {
                        Text(String(format: "%.2f", workoutManager.distance))
                            .font(.title3)
                            .foregroundColor(.white)
                        Text("MI")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Timer
                HStack(spacing: 2) {
                    Text(String(format: "%02d", workoutManager.hours))
                        .font(.title)
                        .foregroundColor(.white)
                    Text(":")
                        .font(.title)
                        .foregroundColor(.gray)
                    Text(String(format: "%02d", workoutManager.minutes))
                        .font(.title)
                        .foregroundColor(.white)
                    Text(":")
                        .font(.title)
                        .foregroundColor(.gray)
                    Text(String(format: "%02d", workoutManager.seconds))
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 20) {
                Button(action: {
                    if workoutManager.isActive {
                        workoutManager.pauseWorkout()
                    } else {
                        if workoutManager.isPaused {
                            workoutManager.resumeWorkout()
                        } else {
                            workoutManager.startWorkout(weight: workoutManager.ruckWeight)
                        }
                    }
                }) {
                    Image(systemName: workoutManager.isActive ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(workoutManager.isActive ? Color.orange : Color.green)
                        .clipShape(Circle())
                }
                
                Button(action: {
                    workoutManager.endWorkout()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.black)
        .focusable()
        .digitalCrownRotation(
            $workoutManager.ruckWeight,
            from: 0,
            through: 100,
            by: 1,
            sensitivity: .medium,
            isContinuous: false
        )
    }
}

#Preview {
    WorkoutView()
        .environmentObject(WorkoutManager())
}
