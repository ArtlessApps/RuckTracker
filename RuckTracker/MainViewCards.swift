import SwiftUI
import Foundation
import CoreData

// MARK: - Apple Watch Hero Section
struct AppleWatchHeroSection: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple Watch")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Start your ruck workout directly from your wrist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "applewatch")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            if workoutManager.isActive {
                ActiveWorkoutStatusCard()
                    .environmentObject(workoutManager)
            } else {
                QuickSetupCard()
                    .environmentObject(workoutManager)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Active Workout Status Card
struct ActiveWorkoutStatusCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Workout Active")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(formatTime(workoutManager.elapsedTime))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f mi", workoutManager.distance))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f lbs", workoutManager.ruckWeight))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Quick Setup Card
struct QuickSetupCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Setup")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    // Start workout logic
                    workoutManager.startWorkout()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
            }
            
            instructionText
        }
        .padding()
        .background(cardBackground)
    }
    
    private var instructionText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. Set your ruck weight")
            Text("2. Press start on your Apple Watch")
            Text("3. Begin your workout")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
    }
}

// MARK: - Quick Stats Dashboard
struct QuickStatsDashboard: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Stats")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                QuickStatCard(
                    title: "Total Workouts",
                    value: "\(workoutDataManager.totalWorkouts)",
                    icon: "figure.walk",
                    color: .blue
                )
                
                QuickStatCard(
                    title: "Total Distance",
                    value: String(format: "%.1f mi", totalDistance),
                    icon: "location",
                    color: .green
                )
                
                QuickStatCard(
                    title: "Avg Weight",
                    value: String(format: "%.0f lbs", averageRuckWeight),
                    icon: "scalemass",
                    color: .orange
                )
                
                QuickStatCard(
                    title: "This Week",
                    value: "\(thisWeekWorkouts)",
                    icon: "calendar",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private var totalDistance: Double {
        workoutDataManager.workouts.reduce(0) { $0 + $1.distance }
    }
    
    private var averageRuckWeight: Double {
        let weights = workoutDataManager.workouts.map { $0.ruckWeight }
        return weights.isEmpty ? 0 : weights.reduce(0, +) / Double(weights.count)
    }
    
    private var thisWeekWorkouts: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        return workoutDataManager.workouts.filter { workout in
            guard let workoutDate = workout.date else { return false }
            return workoutDate >= startOfWeek
        }.count
    }
}


// MARK: - Training Insights Section
struct TrainingInsightsSection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training Insights")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                InsightCard(
                    title: "Weekly Load",
                    value: String(format: "%.1f lbs", weeklyLoad),
                    description: loadDescription,
                    color: .blue
                )
                
                InsightCard(
                    title: "Progress Trend",
                    value: progressTrend,
                    description: trendDescription,
                    color: progressColor
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private var weeklyLoad: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        return workoutDataManager.workouts
            .filter { workout in
                guard let workoutDate = workout.date else { return false }
                return workoutDate >= startOfWeek
            }
            .reduce(0) { $0 + ($1.ruckWeight * $1.distance) }
    }
    
    private var loadDescription: String {
        if weeklyLoad > 100 {
            return "High load! Ensure adequate recovery between sessions."
        } else if weeklyLoad > 50 {
            return "Moderate load. Good balance of training and recovery."
        } else {
            return "Light load. Consider increasing distance or weight."
        }
    }
    
    private var progressTrend: String {
        let recentWorkouts = Array(workoutDataManager.workouts.suffix(5))
        guard recentWorkouts.count >= 3 else { return "Insufficient Data" }
        
        let distances = recentWorkouts.map { $0.distance }
        let isIncreasing = distances.enumerated().dropFirst().allSatisfy { index, distance in
            distance >= distances[index - 1]
        }
        
        return isIncreasing ? "↗️ Improving" : "↘️ Declining"
    }
    
    private var trendDescription: String {
        let recentWorkouts = Array(workoutDataManager.workouts.suffix(5))
        guard recentWorkouts.count >= 3 else { return "Need more data for trend analysis" }
        
        let distances = recentWorkouts.map { $0.distance }
        let isIncreasing = distances.enumerated().dropFirst().allSatisfy { index, distance in
            distance >= distances[index - 1]
        }
        
        return isIncreasing ? "Great progress! Keep up the consistency." : "Consider adjusting your training approach."
    }
    
    private var progressColor: Color {
        let recentWorkouts = Array(workoutDataManager.workouts.suffix(5))
        guard recentWorkouts.count >= 3 else { return .gray }
        
        let distances = recentWorkouts.map { $0.distance }
        let isIncreasing = distances.enumerated().dropFirst().allSatisfy { index, distance in
            distance >= distances[index - 1]
        }
        
        return isIncreasing ? .green : .orange
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}
