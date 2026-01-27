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
            
            QuickSetupCard()
                .environmentObject(workoutManager)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }
}


// MARK: - Quick Setup Card (Simplified)
struct QuickSetupCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showingAdvancedSettings = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Simplified status and settings
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to ruck")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(workoutManager.ruckWeight)) lbs configured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Settings button for progressive disclosure
                Button(action: {
                    showingAdvancedSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Quick tips (replacing 3-step instructions)
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(Color("PrimaryMain"))
                    .font(.caption)
                
                Text("Tap start to begin - watch pairing & weight can be adjusted anytime")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
        }
        .padding()
        .background(cardBackground)
        .sheet(isPresented: $showingAdvancedSettings) {
            // Settings sheet removed - weight selection now handled by WorkoutWeightSelector
            EmptyView()
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
    }
}




// MARK: - Training Insights Section
struct TrainingInsightsSection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Training Insights")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("MARCH Pro")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Color.blue.opacity(0.1)
                                .cornerRadius(4)
                        )
                }
                
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
        
        return isIncreasing ? Color("AccentGreen") : Color("PrimaryMain")
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

