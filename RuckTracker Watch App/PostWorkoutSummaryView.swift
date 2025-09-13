import SwiftUI

struct PostWorkoutSummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("Workout Complete!")
                        .font(.headline)
                        .foregroundColor(.white)
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
                        color: .blue
                    )
                    
                    // Distance
                    StatRow(
                        icon: "location.fill",
                        label: "Distance",
                        value: String(format: "%.2f mi", workoutManager.finalDistance),
                        color: .green
                    )
                    
                    // Calories
                    StatRow(
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(workoutManager.finalCalories))",
                        color: .orange
                    )
                    
                    // Ruck Weight
                    if workoutManager.finalRuckWeight > 0 {
                        StatRow(
                            icon: "figure.hiking",
                            label: "Ruck Weight",
                            value: "\(Int(workoutManager.finalRuckWeight)) lbs",
                            color: .yellow
                        )
                        
                        // Activity Intensity indicator
                        StatRow(
                            icon: "bolt.fill",
                            label: "Intensity",
                            value: intensityLevel,
                            color: intensityColor
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
                            value: String(format: "%d:%02d /mi", minutes, seconds),
                            color: .purple
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
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(25)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.black)
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
    
    private var intensityLevel: String {
        guard workoutManager.finalRuckWeight > 0 else { return "Light" }
        
        // Estimate body weight for intensity calculation
        let estimatedBodyWeight: Double = 170 // Could be from user settings
        let weightPercentage = workoutManager.finalRuckWeight / estimatedBodyWeight
        
        switch weightPercentage {
        case 0..<0.15: return "Moderate"
        case 0.15..<0.25: return "Vigorous"
        default: return "High"
        }
    }
    
    private var intensityColor: Color {
        switch intensityLevel {
        case "Light": return .green
        case "Moderate": return .yellow
        case "Vigorous": return .orange
        case "High": return .red
        default: return .gray
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
                .foregroundColor(.gray)
            
            Spacer()
            
            // Value
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
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
            return manager
        }())
}
