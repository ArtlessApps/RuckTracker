//
//  UniversalChallengeView.swift
//  RuckTracker
//
//  Universal challenge view that works for any challenge type
//

import SwiftUI

struct UniversalChallengeView: View {
    let challenge: StackChallenge
    @StateObject private var challengeManager = ChallengeManager()
    @EnvironmentObject var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
    @State private var showingCompletionConfirmation = false
    @State private var selectedWorkoutForCompletion: ChallengeWorkout?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    if challengeManager.isLoading {
                        LoadingView()
                    } else {
                        // Header with progress
                        headerSection
                        
                        // Challenge workouts list
                        LazyVStack(spacing: 1) {
                            ForEach(challengeManager.workouts, id: \.id) { workout in
                                UniversalWorkoutRowView(
                                    workout: workout,
                                    challenge: challenge,
                                    isCompleted: challengeManager.isWorkoutCompleted(workout.id),
                                    isCurrent: challengeManager.currentWorkout?.id == workout.id,
                                    canComplete: challengeManager.canCompleteWorkout(workout),
                                    onComplete: {
                                        selectedWorkoutForCompletion = workout
                                        showingCompletionConfirmation = true
                                    }
                                )
                            }
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(challenge.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEnrollment) {
            ChallengeEnrollmentView(challenge: challenge, challengeManager: challengeManager)
        }
        .alert("Complete Workout?", isPresented: $showingCompletionConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete") {
                if let workout = selectedWorkoutForCompletion {
                    Task {
                        await challengeManager.completeWorkout(workout)
                    }
                }
            }
        } message: {
            if let workout = selectedWorkoutForCompletion {
                Text("Mark Day \(workout.dayNumber) as completed and advance to the next workout.")
            }
        }
        .task {
            await challengeManager.loadChallenge(challenge)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Progress indicator
            if challengeManager.enrollment != nil {
                progressSection
            } else {
                enrollmentPrompt
            }
            
            // Current day callout
            if let currentWorkout = challengeManager.currentWorkout,
               challengeManager.enrollment != nil {
                CurrentWorkoutCallout(
                    workout: currentWorkout,
                    challenge: challenge
                )
            }
        }
        .padding()
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(challengeManager.completedWorkoutCount)/\(challengeManager.totalWorkoutCount) Workouts Complete")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(challengeManager.progressPercentage * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(challenge.focusArea.color))
            }
            
            ProgressView(value: challengeManager.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(challenge.focusArea.color)))
                .scaleEffect(y: 2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var enrollmentPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: challenge.focusArea.iconName)
                .font(.system(size: 40))
                .foregroundColor(Color(challenge.focusArea.color))
            
            Text("Ready to Start?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enroll in this \(challenge.durationDays)-day challenge to begin tracking your progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                if premiumManager.isPremiumUser {
                    showingEnrollment = true
                } else {
                    premiumManager.showPaywall(context: .featureUpsell)
                }
            }) {
                Text("Enroll in Challenge")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(challenge.focusArea.color))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Universal Workout Row View
struct UniversalWorkoutRowView: View {
    let workout: ChallengeWorkout
    let challenge: StackChallenge
    let isCompleted: Bool
    let isCurrent: Bool
    let canComplete: Bool
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Day indicator
            WorkoutStatusIndicator(
                dayNumber: workout.dayNumber,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                canComplete: canComplete,
                challenge: challenge
            )
            
            // Workout details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: workout.workoutType.iconName)
                        .foregroundColor(Color(challenge.focusArea.color))
                        .font(.title3)
                    
                    Text(workout.getWorkoutTitle(for: challenge))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Dynamic stats based on workout
                    ChallengeWorkoutStatsView(workout: workout)
                }
                
                Text(workout.getInstructions(for: challenge))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            // Complete button
            if !isCompleted && canComplete {
                Button(action: onComplete) {
                    Text("Complete")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(challenge.focusArea.color))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            // Current day highlight
            isCurrent && !isCompleted ? 
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(challenge.focusArea.color), lineWidth: 3)
            : nil
        )
    }
}

// MARK: - Supporting Views
struct WorkoutStatusIndicator: View {
    let dayNumber: Int
    let isCompleted: Bool
    let isCurrent: Bool
    let canComplete: Bool
    let challenge: StackChallenge
    
    var body: some View {
        ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: 50, height: 50)
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.title2)
                    .fontWeight(.bold)
            } else {
                Text("\(dayNumber)")
                    .foregroundColor(isCurrent ? .white : .primary)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
    }
    
    private var circleColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return Color(challenge.focusArea.color)
        } else if canComplete {
            return Color(.systemGray4)
        } else {
            return Color(.systemGray5)
        }
    }
}

struct ChallengeWorkoutStatsView: View {
    let workout: ChallengeWorkout
    
    var body: some View {
        HStack(spacing: 12) {
            if let distance = workout.distanceMiles, !workout.isRestDay {
                StatLabel(
                    icon: "location.fill",
                    value: "\(String(format: "%.1f", distance)) mi"
                )
            }
            
            if let weight = workout.weightLbs, !workout.isRestDay {
                StatLabel(
                    icon: "scalemass.fill",
                    value: "\(Int(weight)) lbs"
                )
            }
            
            if let pace = workout.targetPaceMinutes, !workout.isRestDay {
                let minutes = Int(pace)
                let seconds = Int((pace - Double(minutes)) * 60)
                StatLabel(
                    icon: "speedometer",
                    value: "\(minutes):\(String(format: "%02d", seconds))/mi"
                )
            }
            
            if let duration = workout.durationMinutes {
                StatLabel(
                    icon: "timer",
                    value: "\(duration) min"
                )
            }
        }
    }
}

struct StatLabel: View {
    let icon: String
    let value: String
    
    var body: some View {
        Label(value, systemImage: icon)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct CurrentWorkoutCallout: View {
    let workout: ChallengeWorkout
    let challenge: StackChallenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(Color(challenge.focusArea.color))
                Text("Today's Challenge")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(workout.getWorkoutTitle(for: challenge))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(workout.getInstructions(for: challenge))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !workout.isRestDay {
                HStack(spacing: 16) {
                    if let distance = workout.distanceMiles {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(Color(challenge.focusArea.color))
                            Text("\(String(format: "%.1f", distance)) miles")
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let weight = workout.weightLbs {
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundColor(Color(challenge.focusArea.color))
                            Text("\(Int(weight)) lbs")
                                .fontWeight(.medium)
                        }
                    }
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(challenge.focusArea.color).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(challenge.focusArea.color).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading Challenge...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}
