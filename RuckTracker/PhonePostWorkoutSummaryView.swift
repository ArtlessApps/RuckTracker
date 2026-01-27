
// PhonePostWorkoutSummaryView.swift
// Premium post-workout summary matching the workout view aesthetic
import SwiftUI

struct PhonePostWorkoutSummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAnalytics = false
    @State private var showingShare = false
    @State private var hasScheduledSharePrompt = false
    @State private var perceivedEffort: Double = 5
    @State private var experiencedSoreness: Bool = false
    
    // Final workout stats
    let finalElapsedTime: TimeInterval
    let finalDistance: Double
    let finalCalories: Double
    let finalRuckWeight: Double
    let finalElevationGain: Double
    
    // Rotating congratulatory phrases
    private let congratsPhrases = [
        "Ruck, recorded.",
        "Effort, logged.",
        "The load was carried.",
        "Distance, earned.",
        "Journey, complete.",
        "Weight, lifted."
    ]
    
    init(finalElapsedTime: TimeInterval, finalDistance: Double, finalCalories: Double, finalRuckWeight: Double, finalElevationGain: Double = 0) {
        self.finalElapsedTime = finalElapsedTime
        self.finalDistance = finalDistance
        self.finalCalories = finalCalories
        self.finalRuckWeight = finalRuckWeight
        self.finalElevationGain = finalElevationGain
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            AppColors.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)
                
                // Congratulatory phrase (randomly selected)
                Text(congratsPhrases.randomElement() ?? "Workout complete.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.primary)
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
                    
                    // Elevation
                    StatRowWithUnit(
                        label: "ELEVATION",
                        value: "\(Int(finalElevationGain))",
                        unit: "ft"
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How did it feel?")
                            .font(.headline)
                        .foregroundColor(AppColors.textOnLight)
                        HStack {
                            Text("Easy")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Slider(value: $perceivedEffort, in: 1...10, step: 1)
                            Text("Hard")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Toggle("Soreness or niggles", isOn: $experiencedSoreness)
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.primary.opacity(0.08)))
                    
                    Button(action: {
                        showingShare = true
                    }) {
                        Text("Share this Ruck")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textOnLight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.primary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Done Button
                    Button(action: {
                        let feedback = MarchFeedback(
                            rpe: Int(perceivedEffort),
                            soreness: experiencedSoreness,
                            timestamp: Date()
                        )
                        MarchAdaptationEngine.saveFeedback(feedback)
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.primaryGradient)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // View History Button
                    Button(action: {
                        showingAnalytics = true
                    }) {
                        Text("View Workout History")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(AppColors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(AppColors.primary, lineWidth: 1.5)
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
        .onAppear {
            if !hasScheduledSharePrompt {
                hasScheduledSharePrompt = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showingShare = true
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            WorkoutShareSheet(data: shareData)
                .environmentObject(WorkoutDataManager.shared)
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
    
    private var shareData: WorkoutShareData {
        let latestWorkout = WorkoutDataManager.shared.workouts.first
        let workoutDate = latestWorkout?.date ?? Date()
        let uri = WorkoutDataManager.shared.lastSavedWorkoutURI ?? latestWorkout?.objectID.uriRepresentation()
        return WorkoutShareData(
            title: "Ruck Complete",
            distanceMiles: finalDistance,
            durationSeconds: finalElapsedTime,
            calories: Int(finalCalories),
            ruckWeight: Int(finalRuckWeight),
            elevationGain: Int(finalElevationGain),
            date: workoutDate,
            workoutURI: uri
        )
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
                .foregroundColor(isSecondary ? AppColors.textSecondary : AppColors.textOnLight)
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
                    .foregroundColor(isSecondary ? AppColors.textSecondary : AppColors.textOnLight)
                
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
        finalRuckWeight: 20,
        finalElevationGain: 245
    )
    .environmentObject(WorkoutManager())
}
