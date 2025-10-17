// ActiveWorkoutFullScreenView.swift
// Premium full-screen workout view for iPhone
import SwiftUI

struct ActiveWorkoutFullScreenView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with time and close button
                topBar
                
                Spacer()
                    .frame(height: 40)
                
                // Title - RUCK
                Text("RUCK")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("BackgroundDark"))
                    .tracking(2)
                
                // Program/Challenge name (if available)
                if let programName = workoutManager.currentProgramName,
                   let weekDay = workoutManager.currentWeekDay {
                    Text("\(programName)\nWeek \(weekDay.week), Day \(weekDay.day)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                
                Spacer()
                    .frame(height: 60)
                
                // HERO METRIC - Distance
                Text(String(format: "%.2f", workoutManager.distance))
                    .font(.system(size: 100, weight: .medium))
                    .foregroundColor(Color("BackgroundDark"))
                + Text("mi")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(Color("BackgroundDark"))
                
                Spacer()
                    .frame(height: 50)
                
                // SECONDARY METRICS - 2x2 Grid
                VStack(spacing: 36) {
                    HStack(spacing: 50) {
                        // Pace
                        MetricView(
                            value: formatPace(),
                            label: "min/mi",
                            color: Color("BackgroundDark")
                        )
                        
                        // Calories
                        MetricView(
                            value: "\(Int(workoutManager.calories))",
                            label: "loaded calories",
                            color: Color("BackgroundDark")
                        )
                    }
                    
                    HStack(spacing: 50) {
                        // Workout Time
                        MetricView(
                            value: formatElapsedTime(workoutManager.elapsedTime),
                            label: "Workout Time",
                            color: Color("BackgroundDark")
                        )
                        
                        // Ruck Weight
                        MetricView(
                            value: "\(String(format: "%.0f", workoutManager.ruckWeight))lbs",
                            label: "Ruck weight",
                            color: Color("BackgroundDark")
                        )
                    }
                }
                
                Spacer()
                
                // CONTROL BUTTONS
                HStack(spacing: 40) {
                    // Pause/Resume button
                    Button {
                        workoutManager.togglePause()
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color("AccentCream").opacity(0.15))
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color("AccentCream"))
                            }
                            
                            Text(workoutManager.isPaused ? "Resume" : "Pause")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // End button
                    Button {
                        workoutManager.endWorkout()
                        dismiss()
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.red)
                            }
                            
                            Text("End")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Time (system time)
            Text(Date.now, style: .time)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("BackgroundDark"))
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(workoutManager.isPaused ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                
                Text(workoutManager.isPaused ? "Paused" : "Active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
            }
            
            Spacer()
            
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 50)
    }
    
    // MARK: - Helpers
    
    private func formatElapsedTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func formatPace() -> String {
        guard workoutManager.distance > 0 && workoutManager.elapsedTime > 0 else {
            return "00:00"
        }
        
        let paceInSeconds = workoutManager.elapsedTime / workoutManager.distance
        let mins = Int(paceInSeconds) / 60
        let secs = Int(paceInSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}


// MARK: - WorkoutManager Extensions
// Add these properties to your WorkoutManager if they don't exist

extension WorkoutManager {
    var currentProgramName: String? {
        // Return the current program name if in a program/challenge
        // You'll need to implement this based on your data structure
        return nil
    }
    
    var currentWeekDay: (week: Int, day: Int)? {
        // Return the current week and day if in a program
        // You'll need to implement this based on your data structure
        return nil
    }
}

// MARK: - Preview

#Preview {
    ActiveWorkoutFullScreenView()
        .environmentObject(WorkoutManager())
}