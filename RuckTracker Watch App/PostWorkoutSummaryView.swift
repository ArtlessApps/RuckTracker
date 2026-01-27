import SwiftUI

struct PostWorkoutSummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(AppColors.successGreen)
                    
                    Text("Workout Complete!")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                
                // Main Stats
                VStack(spacing: 12) {
                    // Duration
                    StatRow(
                        icon: "clock.fill",
                        label: "Duration",
                        value: formattedTime(workoutManager.finalElapsedTime),
                        color: AppColors.accentTeal
                    )
                    
                    // Distance
                    StatRow(
                        icon: "location.fill",
                        label: "Distance",
                        value: {
                            let displayDistance = userSettings.preferredDistanceUnit == .miles ? 
                                workoutManager.finalDistance : 
                                workoutManager.finalDistance / userSettings.preferredDistanceUnit.conversionToMiles
                            return String(format: "%.2f %@", displayDistance, userSettings.preferredDistanceUnit.rawValue)
                        }(),
                        color: AppColors.successGreen
                    )
                    
                    // Calories
                    StatRow(
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(workoutManager.finalCalories))",
                        color: AppColors.accentWarm
                    )
                    
                    // Ruck Weight
                    if workoutManager.finalRuckWeight > 0 {
                        StatRow(
                            icon: "figure.hiking",
                            label: "Ruck Weight",
                            value: "\(String(format: "%.0f", workoutManager.finalRuckWeight)) \(userSettings.preferredWeightUnit.rawValue)",
                            color: AppColors.primary
                        )
                    }
                    
                    // Elevation Gain
                    if workoutManager.finalElevationGain > 0 {
                        StatRow(
                            icon: "arrow.up.right",
                            label: "Elevation",
                            value: "\(Int(workoutManager.finalElevationGain)) ft",
                            color: AppColors.successGreen
                        )
                    }
                    
                    // Average Pace (if we have distance)
                    if workoutManager.finalDistance > 0 {
                        let paceMinutes = (workoutManager.finalElapsedTime / 60.0) / workoutManager.finalDistance
                        let minutes = Int(paceMinutes)
                        let seconds = Int((paceMinutes - Double(minutes)) * 60)
                        
                        StatRow(
                            icon: "speedometer",
                            label: "Avg Pace",
                            value: String(format: "%d:%02d /%@", minutes, seconds, userSettings.preferredDistanceUnit.rawValue),
                            color: AppColors.accentTealLight
                        )
                    }
                }
                .padding(.horizontal, 8)
                
                // Done Button
                Button(action: {
                    workoutManager.dismissPostWorkoutSummary()
                }) {
                    HStack {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(25)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
    }
    
    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            // Label
            Text(label)
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            // Value
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(AppColors.surface)
        .cornerRadius(8)
    }
}

#Preview {
    PostWorkoutSummaryView()
        .environmentObject({
            let manager = WorkoutManager()
            manager.finalElapsedTime = 3661 // 1h 1m 1s
            manager.finalDistance = 3.5
            manager.finalCalories = 450
            manager.finalRuckWeight = 35
            manager.finalElevationGain = 180
            return manager
        }())
}
