import SwiftUI

struct PhonePostWorkoutSummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAnalytics = false
    
    // Final workout stats (captured when workout ends)
    let finalElapsedTime: TimeInterval
    let finalDistance: Double
    let finalCalories: Double
    let finalRuckWeight: Double
    
    init(finalElapsedTime: TimeInterval, finalDistance: Double, finalCalories: Double, finalRuckWeight: Double) {
        self.finalElapsedTime = finalElapsedTime
        self.finalDistance = finalDistance
        self.finalCalories = finalCalories
        self.finalRuckWeight = finalRuckWeight
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        // Success Icon
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundColor(.green)
                        
                        VStack(spacing: 8) {
                            Text("Workout Complete!")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Great job on your ruck!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Main Stats Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        // Duration
                        WorkoutStatCard(
                            icon: "clock.fill",
                            title: "Duration",
                            value: formattedTime(finalElapsedTime),
                            color: .blue
                        )
                        
                        // Distance
                        WorkoutStatCard(
                            icon: "location.fill",
                            title: "Distance",
                            value: {
                                let displayDistance = userSettings.preferredDistanceUnit == .miles ? 
                                    finalDistance : 
                                    finalDistance / userSettings.preferredDistanceUnit.conversionToMiles
                                return String(format: "%.2f %@", displayDistance, userSettings.preferredDistanceUnit.rawValue)
                            }(),
                            color: .green
                        )
                        
                        // Calories
                        WorkoutStatCard(
                            icon: "flame.fill",
                            title: "Calories",
                            value: "\(Int(finalCalories))",
                            color: Color("PrimaryMain")
                        )
                        
                        // Ruck Weight
                        WorkoutStatCard(
                            icon: "figure.hiking",
                            title: "Ruck Weight",
                            value: "\(String(format: "%.0f", finalRuckWeight)) \(userSettings.preferredWeightUnit.rawValue)",
                            color: .purple
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Additional Stats (if applicable)
                    if finalDistance > 0 {
                        VStack(spacing: 16) {
                            // Average Pace
                            let paceMinutes = (finalElapsedTime / 60.0) / finalDistance
                            let minutes = Int(paceMinutes)
                            let seconds = Int((paceMinutes - Double(minutes)) * 60)
                            
                            WorkoutStatCard(
                                icon: "speedometer",
                                title: "Average Pace",
                                value: String(format: "%d:%02d /%@", minutes, seconds, userSettings.preferredDistanceUnit.rawValue),
                                color: .indigo,
                                isFullWidth: true
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Done Button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Text("Done")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // View History Button
                        Button(action: {
                            showingAnalytics = true
                        }) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 16, weight: .medium))
                                Text("View Workout History")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Workout Summary")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView(showAllWorkouts: .constant(false))
                .environmentObject(WorkoutDataManager.shared)
                .environmentObject(PremiumManager.shared)
        }
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

struct WorkoutStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var isFullWidth: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            // Value
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Label
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(height: 120)
        .frame(maxWidth: isFullWidth ? .infinity : 140)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        PhonePostWorkoutSummaryView(
            finalElapsedTime: 3661, // 1h 1m 1s
            finalDistance: 3.5,
            finalCalories: 450,
            finalRuckWeight: 35
        )
        .environmentObject(WorkoutManager())
    } else {
        Text("Requires iOS 17.0+")
    }
}
