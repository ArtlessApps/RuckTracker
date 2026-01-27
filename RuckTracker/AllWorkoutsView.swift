//
//  AllWorkoutsView.swift
//  MARCH
//
//  View for displaying all stored workouts
//

import SwiftUI
import CoreData

struct AllWorkoutsView: View {
    let deepLinkShareCode: String?
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingDeleteAlert = false
    @State private var workoutToDelete: WorkoutEntity?
    @State private var shareTarget: WorkoutEntity?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                List {
                if let code = deepLinkShareCode {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You opened a shared ruck")
                                .font(.headline)
                            Text("Code: \(code). View the latest rucks below or start your own.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if workoutDataManager.workouts.isEmpty {
                    Section {
                        VStack(spacing: 20) {
                            Image(systemName: "figure.walk.motion")
                                .font(.system(size: 50))
                                .foregroundColor(AppColors.primary)
                            
                            Text("No Workouts Yet")
                                .font(.headline)
                            
                            Text("Start your first rucking workout to see your progress here.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
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
                                    Button("Share") {
                                        shareTarget = workout
                                        showingShareSheet = true
                                    }
                                    .tint(AppColors.primary)
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
            .sheet(isPresented: $showingShareSheet) {
                if let workout = shareTarget {
                    WorkoutShareSheet(data: shareData(for: workout))
                        .environmentObject(workoutDataManager)
                }
            }
        }
        .onAppear {
            if let code = deepLinkShareCode,
               let workout = workoutFromShareCode(code) {
                shareTarget = workout
                showingShareSheet = true
            }
        }
    }
    
    init(deepLinkShareCode: String? = nil) {
        self.deepLinkShareCode = deepLinkShareCode
    }
    
    private func shareData(for workout: WorkoutEntity) -> WorkoutShareData {
        WorkoutShareData(
            title: "Ruck Complete",
            distanceMiles: workout.distance,
            durationSeconds: workout.duration,
            calories: Int(workout.calories),
            ruckWeight: Int(workout.ruckWeight),
            date: workout.date ?? Date(),
            workoutURI: workout.objectID.uriRepresentation()
        )
    }
    
    private func workoutFromShareCode(_ code: String) -> WorkoutEntity? {
        guard let uri = ShareLinkBuilder.decodeWorkoutURI(from: code),
              let objectId = workoutDataManager.context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri) else {
            return nil
        }
        
        do {
            let object = try workoutDataManager.context.existingObject(with: objectId)
            return object as? WorkoutEntity
        } catch {
            return nil
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
                    .background(Color("PrimaryMain").opacity(0.2))
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
    AllWorkoutsView(deepLinkShareCode: nil)
        .environmentObject(WorkoutDataManager.shared)
}
