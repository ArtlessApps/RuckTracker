// WorkoutView.swift - Updated to use Apple's calculations
import SwiftUI
import HealthKit

struct WorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Status Bar
            HStack {
                // Weight
                HStack(spacing: 2) {
                    Text("\(Int(workoutManager.ruckWeight))")
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .foregroundColor(.white)
                    Text("LBS")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Heart Rate (from Apple's real sensor data)
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                    Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Pace (from Apple's stable distance calculations)
                HStack(spacing: 2) {
                    Text(workoutManager.formattedPace)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(workoutManager.paceColor)
                    Text("/MI")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Spacer()
            
            // Main Content Area
            VStack(spacing: 16) {
                // Stats Row
                HStack {
                    // Calories (Apple's base + our ruck weight adjustment)
                    VStack(spacing: 4) {
                        Text("\(Int(workoutManager.calories))")
                            .font(.system(size: 20, weight: .medium, design: .default))
                            .foregroundColor(.white)
                        Text("CAL")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.gray)
                            .tracking(1)
                        if workoutManager.ruckWeight > 0 {
                            Text("LOADED")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    // Center Hiker Icon
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, isActive: workoutManager.isActive)
                    
                    Spacer()
                    
                    // Distance (from Apple's GPS + motion algorithms)
                    VStack(spacing: 4) {
                        Text(String(format: "%.2f", workoutManager.distance))
                            .font(.system(size: 20, weight: .medium, design: .default))
                            .foregroundColor(.white)
                        Text("MI")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.gray)
                            .tracking(1)
                    }
                }
                .padding(.horizontal, 20)
                
                // Timer Display (from HKLiveWorkoutBuilder.elapsedTime)
                HStack(spacing: 4) {
                    Text(String(format: "%02d", workoutManager.hours))
                        .font(.system(size: 28, weight: .ultraLight, design: .default))
                        .foregroundColor(.white)
                    Text(":")
                        .font(.system(size: 28, weight: .ultraLight, design: .default))
                        .foregroundColor(.gray)
                    Text(String(format: "%02d", workoutManager.minutes))
                        .font(.system(size: 28, weight: .ultraLight, design: .default))
                        .foregroundColor(.white)
                    Text(":")
                        .font(.system(size: 28, weight: .ultraLight, design: .default))
                        .foregroundColor(.gray)
                    Text(String(format: "%02d", workoutManager.seconds))
                        .font(.system(size: 28, weight: .ultraLight, design: .default))
                        .foregroundColor(.white)
                }
                .tracking(2)
            }
            
            Spacer()
            
            // Control Buttons
            HStack(spacing: 24) {
                // Play/Pause Button
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
                    ZStack {
                        Circle()
                            .fill(workoutManager.isActive ? Color.orange : Color.green)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: workoutManager.isActive ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .offset(x: workoutManager.isActive ? 0 : 1.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Stop Button
                Button(action: {
                    workoutManager.endWorkout()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 24)
        }
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
