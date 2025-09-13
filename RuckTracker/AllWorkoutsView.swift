//
//  AllWorkoutsView.swift
//  RuckTracker
//
//  View for displaying all stored workouts
//

import SwiftUI
import CoreData

struct AllWorkoutsView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingDeleteAlert = false
    @State private var workoutToDelete: WorkoutEntity?
    
    var body: some View {
        NavigationView {
            List {
                if workoutDataManager.workouts.isEmpty {
                    Section {
                        VStack(spacing: 20) {
                            Image(systemName: "figure.walk.motion")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("No Workouts Yet")
                                .font(.headline)
                            
                            Text("Start your first rucking workout to see your progress here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    // Summary stats section
                    Section("Summary") {
                        WorkoutStatsView()
                    }
                    
                    // All workouts section
                    Section("All Workouts (\(workoutDataManager.totalWorkouts))") {
                        ForEach(workoutDataManager.workouts, id: \.objectID) { workout in
                            WorkoutDetailRowView(workout: workout)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        workoutToDelete = workout
                                        showingDeleteAlert = true
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("All Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Delete Workout", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let workout = workoutToDelete {
                        workoutDataManager.deleteWorkout(workout)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this workout? This action cannot be undone.")
            }
        }
    }
}

struct WorkoutStatsView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                VStack {
                    Text("\(workoutDataManager.totalWorkouts)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Workouts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    let displayDistance = userSettings.preferredDistanceUnit == .miles ? 
                        workoutDataManager.totalDistance : 
                        workoutDataManager.totalDistance / userSettings.preferredDistanceUnit.conversionToMiles
                    Text(String(format: "%.1f", displayDistance))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(userSettings.preferredDistanceUnit.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(Int(workoutDataManager.totalCalories))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                VStack {
                    let hours = Int(workoutDataManager.totalDuration / 3600)
                    let minutes = Int(workoutDataManager.totalDuration.truncatingRemainder(dividingBy: 3600) / 60)
                    Text("\(hours)h \(minutes)m")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let avgPace = workoutDataManager.averagePace {
                    VStack {
                        let minutes = Int(avgPace)
                        let seconds = Int((avgPace - Double(minutes)) * 60)
                        Text(String(format: "%d:%02d", minutes, seconds))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Avg Pace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct WorkoutDetailRowView: View {
    let workout: WorkoutEntity
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and ruck weight header
            HStack {
                Text(workout.formattedDate)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(workout.ruckWeight)) lbs")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // Main stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.formattedDuration)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.formattedDistance(unit: userSettings.preferredDistanceUnit))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(workout.calories))")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Secondary stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.formattedPace)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(workout.paceColor))
                    Text("Avg Pace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(workout.heartRate))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Avg HR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(workout.weightPercentage(bodyWeightKg: userSettings.bodyWeightInKg))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Body Weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AllWorkoutsView()
        .environmentObject(WorkoutDataManager.shared)
}
