// ActiveWorkoutFullScreenView.swift
// Premium full-screen workout view for iPhone - USES APPCOLORS
import SwiftUI

struct ActiveWorkoutFullScreenView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient - CHANGED: Already uses AppColors ✓
            AppColors.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with time and close button
                topBar
                
                Spacer()
                    .frame(height: 40)
                
                // Title - RUCK
                // CHANGED: Uses AppColors.textPrimary instead of Color("BackgroundDark")
                Text("RUCK")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(2)
                
                // Program/Challenge name (if available)
                if let programName = workoutManager.currentProgramName,
                   let weekDay = workoutManager.currentWeekDay {
                    // CHANGED: Uses AppColors.textSecondary instead of Color("TextSecondary")
                    Text("\(programName)\nWeek \(weekDay.week), Day \(weekDay.day)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                
                Spacer()
                    .frame(height: 60)
                
                // HERO METRIC - Distance
                // CHANGED: Uses AppColors.textPrimary instead of Color("BackgroundDark")
                Text(String(format: "%.2f", workoutManager.distance))
                    .font(.system(size: 100, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                + Text("mi")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                    .frame(height: 50)
                
                // SECONDARY METRICS - 2x2 Grid
                VStack(spacing: 36) {
                    HStack(spacing: 50) {
                        // Pace
                        // CHANGED: Uses AppColors.textPrimary instead of Color("BackgroundDark")
                        WorkoutMetricView(
                            value: formatPace(),
                            label: "min/mi",
                            color: AppColors.textPrimary
                        )
                        
                        // Calories
                        // CHANGED: Uses AppColors.textPrimary instead of Color("BackgroundDark")
                        WorkoutMetricView(
                            value: "\(Int(workoutManager.calories))",
                            label: "loaded calories",
                            color: AppColors.textPrimary
                        )
                    }
                    
                    HStack(spacing: 50) {
                        // Elapsed Time
                        // CHANGED: Uses AppColors.textPrimary instead of Color("BackgroundDark")
                        WorkoutMetricView(
                            value: formatElapsedTime(),
                            label: "elapsed",
                            color: AppColors.textPrimary
                        )
                        
                        // Heart Rate
                        // CHANGED: Uses AppColors.textPrimary instead of Color("BackgroundDark")
                        WorkoutMetricView(
                            value: "\(Int(workoutManager.heartRate))",
                            label: "bpm",
                            color: AppColors.textPrimary
                        )
                    }
                }
                
                Spacer()
                
                // Action Buttons at bottom
                actionButtons
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Spacer()
            
            // Current Time
            // CHANGED: Uses AppColors.textSecondary instead of Color("TextSecondary")
            Text(currentTimeString())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            // Close Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    // CHANGED: Uses AppColors.textSecondary instead of hardcoded color
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Pause/Resume Button
            Button(action: {
                if workoutManager.isActive {
                    workoutManager.pauseWorkout()
                } else {
                    workoutManager.resumeWorkout()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: workoutManager.isActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        // CHANGED: Uses AppColors instead of hardcoded colors
                        .foregroundColor(workoutManager.isActive ? AppColors.pauseOrange : AppColors.successGreen)
                    
                    Text(workoutManager.isActive ? "Pause" : "Resume")
                        .font(.caption)
                        // CHANGED: Uses AppColors.textSecondary
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // End Workout Button
            Button(action: {
                workoutManager.endWorkout()
                dismiss()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 44))
                        // CHANGED: Uses AppColors.destructiveRed instead of hardcoded .red
                        .foregroundColor(AppColors.destructiveRed)
                    
                    Text("End")
                        .font(.caption)
                        // CHANGED: Uses AppColors.textSecondary
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Helpers
    
    /// Formats the elapsed time as HH:MM:SS
    private func formatElapsedTime() -> String {
        let hours = workoutManager.hours
        let minutes = workoutManager.minutes
        let seconds = workoutManager.seconds
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Formats pace as MM:SS per mile
    private func formatPace() -> String {
        guard workoutManager.distance > 0 else { return "--:--" }
        
        let totalMinutes = workoutManager.elapsedTime / 60.0
        let paceMinutesPerMile = totalMinutes / workoutManager.distance
        
        let minutes = Int(paceMinutesPerMile)
        let seconds = Int((paceMinutesPerMile - Double(minutes)) * 60)
        
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Returns current time as string (e.g., "2:30 PM")
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Metric View Component
/// A reusable component for displaying workout metrics
/// - Parameters:
///   - value: The main metric value (e.g., "12:34", "450")
///   - label: The description label (e.g., "min/mi", "calories")
///   - color: The color for both value and label text
struct WorkoutMetricView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            // Main value - large and bold
            Text(value)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(color)
            
            // Label - small and descriptive
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(color.opacity(0.7))
        }
    }
}

// MARK: - Program Context (optional)
extension WorkoutManager {
    /// Optional context for the active workout screen header.
    /// Implement with real program/challenge state when available.
    var currentProgramName: String? { nil }
    
    /// Optional week/day for program context in the active workout screen header.
    /// Implement with real program/challenge state when available.
    var currentWeekDay: (week: Int, day: Int)? { nil }
}

#Preview {
    ActiveWorkoutFullScreenView()
        .environmentObject(WorkoutManager())
}
