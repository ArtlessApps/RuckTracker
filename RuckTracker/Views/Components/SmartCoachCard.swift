import SwiftUI

// MARK: - Smart Coach Card
/// The top card on the Dashboard. Determines the user's training state and
/// surfaces the single most important action: either continuing their plan
/// or starting an open-goal ruck.
struct SmartCoachCard: View {
    // MARK: - Data
    /// The next scheduled workout from the user's active program (nil when no plan).
    let nextWorkout: ScheduledWorkout?
    /// Title of the active program (e.g. "GORUCK Selection Prep").
    let programTitle: String?
    
    // MARK: - Actions
    /// Fires when the user taps "START MISSION" (active plan).
    let onStartMission: (ScheduledWorkout) -> Void
    /// Fires when the user taps "JUST RUCK" (open-goal fallback or sub-action).
    let onJustRuck: () -> Void
    /// Fires when the user taps "Build a Training Plan" (navigates to Plan tab).
    let onBuildPlan: () -> Void
    
    // MARK: - Body
    var body: some View {
        Group {
            if let workout = nextWorkout, programTitle != nil {
                activePlanContent(workout: workout)
            } else {
                noPlanContent
            }
        }
    }
    
    // MARK: - Active Plan State
    
    private func activePlanContent(workout: ScheduledWorkout) -> some View {
        VStack(spacing: 0) {
            // Eyebrow
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                Text((programTitle ?? "TRAINING PLAN").uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Day badge
                if let day = workout.dayNumber {
                    Text("DAY \(day)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.textPrimary.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppColors.textPrimary.opacity(0.1))
                        )
                }
            }
            .padding(.bottom, 14)
            
            // Workout info
            VStack(alignment: .leading, spacing: 6) {
                Text(workoutTitle(for: workout))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Stats row
                HStack(spacing: 16) {
                    if let distance = workoutDistance(for: workout), distance > 0 {
                        Label("\(String(format: "%.1f", distance)) mi", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Label(durationEstimate(for: workout), systemImage: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Label(intensityLabel(for: workout), systemImage: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.bottom, 20)
            
            // Hero button: START MISSION
            Button {
                onStartMission(workout)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "scope")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("START MISSION")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.primaryGradient)
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 12, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            
            // Sub-action: Just Ruck
            Button {
                onJustRuck()
            } label: {
                Text("Just Ruck")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground)
    }
    
    // MARK: - No Plan State
    
    private var noPlanContent: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "figure.walk")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.primary)
            }
            .padding(.bottom, 16)
            
            // Title
            Text("Ready to Ruck?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.bottom, 6)
            
            Text("Open Goal  •  GPS Tracking")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 22)
            
            // Hero button: JUST RUCK
            Button {
                onJustRuck()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("JUST RUCK")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.primaryGradient)
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 12, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            
            // Sub-action: Build a Training Plan
            Button {
                onBuildPlan()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                    
                    Text("Build a Training Plan")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppColors.primary)
                .padding(.top, 14)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground)
    }
    
    // MARK: - Shared Card Chrome
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.primary.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.15), radius: 20, x: 0, y: 8)
    }
    
    // MARK: - Helpers
    
    private func workoutTitle(for workout: ScheduledWorkout) -> String {
        // "Day X: Workout Title"
        if let day = workout.dayNumber {
            return "Day \(day): \(workout.workoutType.capitalized)"
        }
        return workout.title
    }
    
    private func workoutDistance(for workout: ScheduledWorkout) -> Double? {
        // Parse distance from description (format: "Target: X.X miles")
        let desc = workout.description
        if desc.lowercased().contains("target:") {
            let parts = desc.components(separatedBy: " ")
            for part in parts {
                if let val = Double(part) {
                    return val
                }
            }
        }
        return nil
    }
    
    private func durationEstimate(for workout: ScheduledWorkout) -> String {
        switch workout.workoutType.lowercased() {
        case "recovery ruck": return "40 min"
        case "pace pusher ruck": return "50 min"
        case "vertical grind ruck": return "45 min"
        case "standard test ruck": return "90 min"
        default: return "60 min"
        }
    }
    
    private func intensityLabel(for workout: ScheduledWorkout) -> String {
        switch workout.workoutType.lowercased() {
        case "recovery ruck": return "Low"
        case "pace pusher ruck": return "Medium"
        case "vertical grind ruck": return "Medium"
        case "standard test ruck": return "High"
        default: return "Medium"
        }
    }
}

// MARK: - Preview

#Preview("Active Plan") {
    ZStack {
        AppColors.backgroundGradient
            .ignoresSafeArea()
        
        SmartCoachCard(
            nextWorkout: ScheduledWorkout(
                date: Date(),
                weekNumber: 2,
                title: "Week 2 - Pace Pusher Ruck",
                description: "Target: 3.5 miles",
                workoutID: UUID().uuidString,
                dayNumber: 8,
                workoutType: "Pace Pusher Ruck"
            ),
            programTitle: "GORUCK Selection Prep",
            onStartMission: { _ in },
            onJustRuck: {},
            onBuildPlan: {}
        )
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}

#Preview("No Plan") {
    ZStack {
        AppColors.backgroundGradient
            .ignoresSafeArea()
        
        SmartCoachCard(
            nextWorkout: nil,
            programTitle: nil,
            onStartMission: { _ in },
            onJustRuck: {},
            onBuildPlan: {}
        )
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
