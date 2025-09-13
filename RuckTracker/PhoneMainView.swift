import SwiftUI

struct PhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showingWorkoutView = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    Text("RuckTracker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your weighted walks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Current Session Info or Quick Start
                if workoutManager.isActive {
                    ActiveWorkoutCard()
                } else {
                    QuickStartCard()
                }
                
                Spacer()
                
                // History/Stats Preview
                RecentWorkoutsCard()
            }
            .padding()
            .navigationBarHidden(false)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingWorkoutView) {
                PhoneWorkoutView()
                    .environmentObject(workoutManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct QuickStartCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var showingWorkout = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Weight display - less prominent but still visible
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ruck Weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.0f", workoutManager.ruckWeight))")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(userSettings.preferredWeightUnit.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Quick adjustment buttons - subtle
                HStack(spacing: 12) {
                    Button("-5") {
                        if workoutManager.ruckWeight >= 5 {
                            workoutManager.ruckWeight -= 5
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                    .font(.caption)
                    
                    Button("+5") {
                        workoutManager.ruckWeight += 5
                    }
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                    .font(.caption)
                }
                .foregroundColor(.primary)
            }
            
            // Prominent start button
            Button(action: {
                showingWorkout = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "figure.hiking")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Rucking")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Best tracking on Apple Watch")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(15)
            }
            .sheet(isPresented: $showingWorkout) {
                PhoneWorkoutView()
                    .environmentObject(workoutManager)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct ActiveWorkoutCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Active Workout")
                    .font(.headline)
                
                Spacer()
                
                // Show weight during active workout
                HStack(spacing: 4) {
                    Text("\(String(format: "%.0f", workoutManager.ruckWeight))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(userSettings.preferredWeightUnit.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 30) {
                VStack {
                    Text(workoutManager.formattedElapsedTime)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    let displayDistance = userSettings.preferredDistanceUnit == .miles ? 
                        workoutManager.distance : 
                        workoutManager.distance / userSettings.preferredDistanceUnit.conversionToMiles
                    Text(String(format: "%.2f", displayDistance))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(userSettings.preferredDistanceUnit.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(Int(workoutManager.calories))")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                Button(workoutManager.isPaused ? "Resume" : "Pause") {
                    workoutManager.togglePause()
                }
                .foregroundColor(workoutManager.isPaused ? .green : .orange)
                
                Button("End Workout") {
                    workoutManager.endWorkout()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct PhoneWorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Use Apple Watch reminder
                VStack(spacing: 15) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Best Experience on Apple Watch")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("For accurate GPS tracking, heart rate monitoring, and calorie calculation, start your workout on Apple Watch.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(15)
                
                // Current weight display
                VStack(spacing: 8) {
                    Text("Current Weight Setting")
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.0f", workoutManager.ruckWeight))")
                            .font(.system(size: 48, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                        Text(userSettings.preferredWeightUnit.rawValue.uppercased())
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Basic phone tracking option
                VStack(spacing: 15) {
                    Button("Track on iPhone") {
                        workoutManager.startWorkout()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    
                    Text("Limited accuracy without Apple Watch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct RecentWorkoutsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Workouts")
                .font(.headline)
            
            Text("No recent workouts")
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

#Preview {
    PhoneMainView()
        .environmentObject(WorkoutManager())
}
