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
        VStack(spacing: 16) {
            // Status and Time Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(workoutManager.isPaused ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(workoutManager.isPaused ? 1.0 : 1.2)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: workoutManager.isPaused)
                    
                    Text(workoutManager.isPaused ? "Workout Paused" : "Workout Active")
                        .font(.headline)
                        .foregroundColor(workoutManager.isPaused ? .orange : .green)
                }
                
                Spacer()
                
                Text(formatTime(workoutManager.elapsedTime))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            // Stats Row
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.2f mi", workoutManager.distance))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.0f lbs", workoutManager.ruckWeight))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.0f", workoutManager.calories))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("Heart Rate")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(workoutManager.formattedHeartRate)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(workoutManager.currentHeartRate > 0 ? .red : .white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Control Buttons
            HStack(spacing: 16) {
                // Pause/Resume Button
                Button(action: {
                    workoutManager.togglePause()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text(workoutManager.isPaused ? "Resume" : "Pause")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(workoutManager.isPaused ? Color.green : Color.orange)
                    )
                }
                .buttonStyle(.plain)
                
                // Stop Button
                Button(action: {
                    workoutManager.endWorkout()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Stop")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black,
                            Color.black.opacity(0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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
                    .foregroundColor(.orange)
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
            QuickSettingsSheet()
                .environmentObject(workoutManager)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
    }
}

// MARK: - Quick Settings Sheet (Progressive Disclosure)
struct QuickSettingsSheet: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    @State private var tempRuckWeight: Double
    
    init() {
        // Initialize with current weight - will be updated in onAppear
        _tempRuckWeight = State(initialValue: 20.0)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Weight setting
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ruck Weight")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("\(Int(tempRuckWeight)) lbs")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Stepper("", value: $tempRuckWeight, in: 10...100, step: 5)
                            .labelsHidden()
                    }
                    
                    Slider(value: $tempRuckWeight, in: 10...100, step: 5)
                        .accentColor(.blue)
                    
                    Text("Accurate weight tracking enables precise calorie calculations based on military research")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Watch integration info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple Watch")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "applewatch")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enhanced Experience")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("GPS tracking, heart rate monitoring, and notifications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Workout Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        workoutManager.ruckWeight = tempRuckWeight
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempRuckWeight = workoutManager.ruckWeight
        }
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
                HStack {
                    Text("Training Insights")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("RuckTracker Pro")
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

