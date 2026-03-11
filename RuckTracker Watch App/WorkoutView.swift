// WorkoutView.swift - Updated to use Apple's calculations
import SwiftUI
import HealthKit

struct WorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(alignment: .center, spacing: 0) {

                // ── LEFT COLUMN: all metrics ─────────────────────────
                VStack(alignment: .leading, spacing: 0) {

                    // Weight — top left
                    HStack(spacing: 3) {
                        Text("\(String(format: "%.0f", workoutManager.ruckWeight))")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.primary)
                        Text(userSettings.preferredWeightUnit.rawValue.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.primary.opacity(0.6))
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 6)

                    // TIMER — hero metric
                    RuckStatRow(
                        value: workoutManager.formattedElapsedTime,
                        label: nil,
                        valueSize: 36,
                        valueColor: AppColors.primary,
                        labelColor: AppColors.textSecondary
                    )

                    // DISTANCE
                    RuckStatRow(
                        value: String(format: "%.2f",
                            userSettings.preferredDistanceUnit == .miles
                                ? workoutManager.distance * 0.000621371
                                : workoutManager.distance / 1000),
                        label: userSettings.preferredDistanceUnit.rawValue.uppercased(),
                        valueSize: 26,
                        valueColor: .white,
                        labelColor: AppColors.textSecondary
                    )

                    // CALORIES
                    RuckStatRow(
                        value: "\(Int(workoutManager.calories))",
                        label: "CAL LOADED",
                        valueSize: 20,
                        valueColor: .white,
                        labelColor: AppColors.textSecondary
                    )

                    // PACE
                    RuckStatRow(
                        value: workoutManager.formattedPace,
                        label: "/\(userSettings.preferredDistanceUnit.rawValue.uppercased())",
                        valueSize: 20,
                        valueColor: workoutManager.paceColor,
                        labelColor: AppColors.textSecondary
                    )

                    // HEART RATE
                    RuckStatRow(
                        value: workoutManager.heartRate > 0
                            ? "\(Int(workoutManager.heartRate))"
                            : "--",
                        label: "BPM ♥",
                        valueSize: 20,
                        valueColor: .white,
                        labelColor: .red
                    )

                    // ELEVATION
                    RuckStatRow(
                        value: "↑ \(String(format: "%.0f", workoutManager.elevationGain * 3.28084))",
                        label: "FT",
                        valueSize: 16,
                        valueColor: AppColors.textSecondary,
                        labelColor: AppColors.textSecondary.opacity(0.6)
                    )

                    Spacer()
                }
                .padding(.leading, 12)

                Spacer()

                // ── RIGHT COLUMN: buttons ────────────────────────────
                // Two buttons stacked vertically, centered on right edge.
                // Before workout starts: single green play button.
                // While active: orange pause + red stop.
                // While paused: green play + red stop.
                VStack(spacing: 14) {

                    if !workoutManager.isActive && !workoutManager.isPaused {
                        // ── PRE-WORKOUT: just a big green start ──
                        WatchButton(
                            icon: "play.fill",
                            color: AppColors.primary,
                            offset: 1.5
                        ) {
                            workoutManager.startWorkout(weight: workoutManager.ruckWeight)
                        }

                    } else {
                        // ── ACTIVE or PAUSED: pause/play + stop ──

                        // Top button: pause (orange) when running, play (green) when paused
                        // isPaused takes priority — isActive stays true while paused
                        WatchButton(
                            icon: workoutManager.isPaused ? "play.fill" : "pause.fill",
                            color: workoutManager.isPaused ? AppColors.primary : AppColors.pauseOrange,
                            offset: workoutManager.isPaused ? 1.5 : 0
                        ) {
                            if workoutManager.isPaused {
                                workoutManager.resumeWorkout()
                            } else {
                                workoutManager.pauseWorkout()
                            }
                        }

                        // Bottom button: stop (red) — ends workout
                        WatchButton(
                            icon: "stop.fill",
                            color: AppColors.destructiveRed,
                            offset: 0
                        ) {
                            workoutManager.endWorkout()
                        }
                    }
                }
                .padding(.trailing, 10)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct RuckStatRow: View {
    let value: String
    let label: String?
    let valueSize: CGFloat
    let valueColor: Color
    let labelColor: Color

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text(value)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let label = label {
                Text(label)
                    .font(.system(size: max(valueSize * 0.38, 9), weight: .medium))
                    .foregroundColor(labelColor)
                    .padding(.bottom, 2)
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct WatchButton: View {
    let icon: String
    let color: Color
    let offset: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 38, height: 38)
                    .shadow(color: color.opacity(0.45), radius: 6, x: 0, y: 0)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .offset(x: offset)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WorkoutView()
        .environmentObject(WorkoutManager())
}
