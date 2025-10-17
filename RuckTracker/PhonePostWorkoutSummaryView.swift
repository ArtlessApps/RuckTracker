
// PhonePostWorkoutSummaryView.swift
// Premium post-workout summary matching the workout view aesthetic
import SwiftUI

struct PhonePostWorkoutSummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAnalytics = false
    
    // Final workout stats
    let finalElapsedTime: TimeInterval
    let finalDistance: Double
    let finalCalories: Double
    let finalRuckWeight: Double
    
    // Rotating congratulatory phrases
    private let congratsPhrases = [
        "Ruck, recorded.",
        "Effort, logged.",
        "The load was carried.",
        "Distance, earned.",
        "Journey, complete.",
        "Weight, lifted."
    ]
    
    init(finalElapsedTime: TimeInterval, finalDistance: Double, finalCalories: Double, finalRuckWeight: Double) {
        self.finalElapsedTime = finalElapsedTime
        self.finalDistance = finalDistance
        self.finalCalories = finalCalories
        self.finalRuckWeight = finalRuckWeight
    }
    
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)
                
                // Congratulatory phrase (randomly selected)
                Text(congratsPhrases.randomElement() ?? "Workout complete.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color("PrimaryMain"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 60)
                
                // Stats List - Clean table format
                VStack(spacing: 0) {
                    // Weight
                    StatRowWithUnit(
                        label: "WEIGHT",
                        value: String(format: "%.0f", finalRuckWeight),
                        unit: "lbs"
                    )
                    
                    // Distance
                    StatRowWithUnit(
                        label: "DISTANCE",
                        value: String(format: "%.2f", finalDistance),
                        unit: "mi"
                    )
                    
                    // Pace
                    StatRowWithUnit(
                        label: "PACE",
                        value: formatPaceNumber(),
                        unit: "min/mi"
                    )
                    
                    // Time
                    StatRow(
                        label: "TIME",
                        value: formatTime(finalElapsedTime)
                    )
                    
                    // Calories
                    StatRowWithUnit(
                        label: "CALORIES",
                        value: "\(Int(finalCalories))",
                        unit: "kcal"
                    )
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Done Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color("PrimaryMain"))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // View History Button
                    Button(action: {
                        showingAnalytics = true
                    }) {
                        Text("View Workout History")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color("PrimaryMain"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color("PrimaryMain"), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView(showAllWorkouts: .constant(false))
                .environmentObject(WorkoutDataManager.shared)
                .environmentObject(PremiumManager.shared)
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatPaceNumber() -> String {
        guard finalDistance > 0 && finalElapsedTime > 0 else {
            return "00:00"
        }
        
        let paceInSeconds = finalElapsedTime / finalDistance
        let mins = Int(paceInSeconds) / 60
        let secs = Int(paceInSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Stat Row Component

struct StatRow: View {
    let label: String
    let value: String
    var isSecondary: Bool = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color("TextSecondary"))
                .tracking(1)
                .frame(width: 90, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 44, weight: .regular))
                .foregroundColor(isSecondary ? Color("TextSecondary") : Color("BackgroundDark"))
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
    }
}

// MARK: - Stat Row with Unit Component

struct StatRowWithUnit: View {
    let label: String
    let value: String
    let unit: String
    var isSecondary: Bool = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color("TextSecondary"))
                .tracking(1)
                .frame(width: 90, alignment: .leading)
            
            Spacer()
            
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundColor(isSecondary ? Color("TextSecondary") : Color("BackgroundDark"))
                
                Text(unit)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isSecondary ? Color("TextSecondary").opacity(0.5) : Color("TextSecondary").opacity(0.6))
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    PhonePostWorkoutSummaryView(
        finalElapsedTime: 3661,
        finalDistance: 3.42,
        finalCalories: 326,
        finalRuckWeight: 20
    )
    .environmentObject(WorkoutManager())
}
