//
//  WorkoutCommunityIntegration.swift
//  MARCH
//
//  Handles automatic posting of workouts to clubs after completion
//

import Foundation
import SwiftUI

extension WorkoutManager {
    
    /// Call this after saving a workout to post it to user's clubs
    /// Add this to your existing saveWorkout() or endWorkout() flow
    func shareWorkoutToClubs(
        workoutId: UUID,
        distance: Double,
        duration: Int,
        weight: Double,
        calories: Int,
        elevationGain: Double = 0
    ) async {
        let communityService = CommunityService.shared
        
        // Only share if user is authenticated
        guard communityService.currentProfile != nil else {
            print("⚠️ User not authenticated, skipping community share")
            return
        }
        
        // Only share if user has clubs
        guard !communityService.myClubs.isEmpty else {
            print("⚠️ User has no clubs, skipping community share")
            return
        }
        
        // Post to ALL of the user's clubs
        for club in communityService.myClubs {
            do {
                try await communityService.postWorkout(
                    clubId: club.id,
                    distance: distance,
                    duration: duration,
                    weight: weight,
                    calories: calories,
                    elevationGain: elevationGain,
                    caption: nil, // User can add captions in v2
                    workoutId: workoutId
                )
                
                print("✅ Posted workout to club: \(club.name)")
                
            } catch {
                print("❌ Failed to post workout to \(club.name): \(error)")
                // Continue posting to other clubs even if one fails
            }
        }
    }
}

// MARK: - Post-Workout Share Sheet

/// Optional: Show a sheet after workout with share options
struct PostWorkoutShareSheet: View {
    let workoutId: UUID
    let distance: Double
    let duration: Int
    let weight: Double
    let calories: Int
    let elevationGain: Double
    
    init(workoutId: UUID, distance: Double, duration: Int, weight: Double, calories: Int, elevationGain: Double = 0) {
        self.workoutId = workoutId
        self.distance = distance
        self.duration = duration
        self.weight = weight
        self.calories = calories
        self.elevationGain = elevationGain
    }
    
    @StateObject private var communityService = CommunityService.shared
    @State private var selectedClubs: Set<UUID> = []
    @State private var caption = ""
    @State private var isSharing = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Workout summary
                    workoutSummaryView
                    
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))
                    
                    // Caption input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a caption (optional)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $caption)
                            .frame(height: 80)
                            .padding(8)
                            .background(AppColors.surface)
                            .cornerRadius(8)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding()
                    
                    // Club selection
                    if !communityService.myClubs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Share with clubs")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal)
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(communityService.myClubs) { club in
                                        ClubToggleRow(
                                            club: club,
                                            isSelected: selectedClubs.contains(club.id)
                                        ) {
                                            if selectedClubs.contains(club.id) {
                                                selectedClubs.remove(club.id)
                                            } else {
                                                selectedClubs.insert(club.id)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Share button
                    Button(action: { shareWorkout() }) {
                        if isSharing {
                            ProgressView()
                                .tint(AppColors.textOnLight)
                        } else {
                            Text("Share Workout")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedClubs.isEmpty || isSharing)
                    .padding()
                }
            }
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear {
            // Pre-select all clubs by default
            selectedClubs = Set(communityService.myClubs.map { $0.id })
        }
    }
    
    private var workoutSummaryView: some View {
        HStack(spacing: 16) {
            WorkoutStatColumn(icon: "figure.walk", value: String(format: "%.1f", distance), unit: "mi")
            WorkoutStatColumn(icon: "clock", value: "\(duration)", unit: "min")
            if elevationGain > 0 {
                WorkoutStatColumn(icon: "arrow.up.right", value: "\(Int(elevationGain))", unit: "ft")
            }
            WorkoutStatColumn(icon: "scalemass", value: "\(Int(weight))", unit: "lbs")
            WorkoutStatColumn(icon: "flame", value: "\(calories)", unit: "cal")
        }
        .padding()
    }
    
    private func shareWorkout() {
        isSharing = true
        
        Task {
            for clubId in selectedClubs {
                do {
                    try await communityService.postWorkout(
                        clubId: clubId,
                        distance: distance,
                        duration: duration,
                        weight: weight,
                        calories: calories,
                        elevationGain: elevationGain,
                        caption: caption.isEmpty ? nil : caption,
                        workoutId: workoutId
                    )
                } catch {
                    print("❌ Failed to share to club: \(error)")
                }
            }
            
            isSharing = false
            dismiss()
        }
    }
}

struct WorkoutStatColumn: View {
    let icon: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.primary)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text(unit)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

struct ClubToggleRow: View {
    let club: Club
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                
                Text(club.name)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Text("\(club.memberCount) members")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.primary.opacity(0.15) : AppColors.surface)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Integration with WorkoutManager

/// INSTRUCTIONS FOR INTEGRATION:
/// 
/// 1. In WorkoutManager.swift, find your saveWorkout() or endWorkout() method
/// 
/// 2. After successfully saving the workout to CoreData, add this:
/// 
///    Task {
///        await shareWorkoutToClubs(
///            workoutId: newWorkout.id,
///            distance: finalDistance,
///            duration: Int(finalElapsedTime / 60),
///            weight: finalRuckWeight,
///            calories: finalCalories
///        )
///    }
/// 
/// 3. OR, show the PostWorkoutShareSheet to let users choose clubs:
/// 
///    In your post-workout summary view, add:
/// 
///    .sheet(isPresented: $showingShareSheet) {
///        PostWorkoutShareSheet(
///            workoutId: workoutId,
///            distance: distance,
///            duration: duration,
///            weight: weight,
///            calories: calories
///        )
///    }

// MARK: - Example Integration Code

/*
// Add to your WorkoutManager.swift

func endWorkout() async {
    // ... existing workout end logic ...
    
    // Save to CoreData
    let workoutId = UUID()
    saveWorkout(id: workoutId, distance: finalDistance, ...)
    
    // Auto-share to clubs (background)
    Task {
        await shareWorkoutToClubs(
            workoutId: workoutId,
            distance: finalDistance,
            duration: Int(finalElapsedTime / 60),
            weight: finalRuckWeight,
            calories: finalCalories
        )
    }
}
*/

// MARK: - Premium Gating (Optional)

/// If you want to make community features premium-only:
/// 
/// In CommunityTribeView.swift, add this check:

extension CommunityTribeView {
    var isPremiumFeature: Bool {
        // Check if user has premium
        !PremiumManager.shared.isPremiumUser
    }
    
    // Then in the body, show paywall if not premium:
    // if isPremiumFeature {
    //     PremiumFeatureLockedView(feature: "Community")
    // } else {
    //     // Show normal community view
    // }
}

