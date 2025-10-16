//
//  UniversalChallengeView.swift
//  RuckTracker
//
//  Universal challenge view that works for any challenge type
//

import SwiftUI

struct UniversalChallengeView: View {
    let challenge: Challenge
    @Binding var isPresentingWorkoutFlow: Bool
    @StateObject private var challengeManager = ChallengeManager()
    @EnvironmentObject var challengeService: LocalChallengeService
    @EnvironmentObject var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
    @State private var showingLeaveWarning = false
    @State private var selectedWorkout: ChallengeWorkout?
    
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
                        LazyVStack(spacing: 0) {
                            ForEach(Array(challengeManager.workouts.enumerated()), id: \.element.id) { index, workout in
                                UniversalWorkoutRowView(
                                    workout: workout,
                                    challenge: challenge,
                                    index: workout.dayNumber,
                                    isCompleted: challengeManager.isWorkoutCompleted(workout.id),
                                    isLocked: challengeManager.isWorkoutLocked(workout)
                                )
                                .onTapGesture {
                                    if !challengeManager.isWorkoutLocked(workout) {
                                        selectedWorkout = workout
                                        isPresentingWorkoutFlow = true
                                    }
                                }
                                
                                if index < challengeManager.workouts.count - 1 {
                                    Divider()
                                        .padding(.leading, 80)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(challenge.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLeaveWarning = true
                    } label: {
                        Label("Leave", systemImage: "xmark.circle")
                            .foregroundColor(.red)
                    }
                }
                
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
        .sheet(isPresented: $isPresentingWorkoutFlow) {
            if let workout = selectedWorkout {
                ChallengeWorkoutDetailView(
                    workout: workout,
                    challenge: challenge,
                    challengeManager: challengeManager,
                    isPresentingWorkoutFlow: $isPresentingWorkoutFlow
                )
            }
        }
        .sheet(isPresented: $showingLeaveWarning) {
            if let progress = challengeService.challengeProgress {
                let workoutCount = WorkoutDataManager.shared.getWorkoutCount(forChallengeId: challenge.id)
                
                LeaveWarningDialog(
                    type: .challenge,
                    name: challenge.title,
                    completedCount: progress.currentDay - 1,
                    totalCount: challenge.durationDays,
                    workoutCount: workoutCount,
                    onLeave: {
                        leaveChallenge()
                    },
                    onCancel: {
                        showingLeaveWarning = false
                    }
                )
            }
        }
        .task {
            await challengeManager.loadChallenge(challenge)
        }
    }
    
    private func leaveChallenge() {
        challengeService.unenrollFromChallenge()
        showingLeaveWarning = false
        dismiss()
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Progress indicator
            if challengeManager.enrollment != nil {
                progressSection
            } else {
                enrollmentPrompt
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
    let challenge: Challenge
    let index: Int
    let isCompleted: Bool
    let isLocked: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                } else {
                    Text("\(index)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                }
            }
            
            // Middle: Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.getWorkoutTitle(for: challenge))
                    .font(.headline)
                    .foregroundColor(isLocked ? .secondary : .primary)
                
                Text(workout.displaySubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let instructions = workout.instructions {
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Right: Chevron or lock
            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(isLocked ? Color.clear : Color(.systemBackground))
        .contentShape(Rectangle())
        .opacity(isLocked ? 0.6 : 1.0)
    }
    
    private var statusColor: Color {
        if isCompleted {
            return .green
        } else if isLocked {
            return .gray
        } else {
            return .blue
        }
    }
}

// MARK: - Supporting Views
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

// MARK: - Challenge Workout Detail View
struct ChallengeWorkoutDetailView: View {
    let workout: ChallengeWorkout
    let challenge: Challenge
    @ObservedObject var challengeManager: ChallengeManager
    @Binding var isPresentingWorkoutFlow: Bool
    @EnvironmentObject private var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompletionConfirmation = false
    @State private var isCompleting = false
    @State private var selectedWorkoutWeight: Double = 0
    
    var isCompleted: Bool {
        challengeManager.isWorkoutCompleted(workout.id)
    }
    
    var isLocked: Bool {
        challengeManager.isWorkoutLocked(workout)
    }
    
    init(workout: ChallengeWorkout, challenge: Challenge, challengeManager: ChallengeManager, isPresentingWorkoutFlow: Binding<Bool>) {
        self.workout = workout
        self.challenge = challenge
        self.challengeManager = challengeManager
        self._isPresentingWorkoutFlow = isPresentingWorkoutFlow
        // Initialize with recommended or default weight
        self._selectedWorkoutWeight = State(initialValue: workout.weightLbs ?? UserSettings.shared.defaultRuckWeight)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Workout header
                    workoutHeader
                    
                    // Weight Selector (only for ruck workouts, not rest days)
                    if !workout.isRestDay {
                        weightSelectorSection
                    }
                    
                    // Instructions
                    if let instructions = workout.instructions {
                        instructionsSection(instructions)
                    }
                    
                    // Completion status or action
                    if isCompleted {
                        completedSection
                    } else if !isLocked {
                        actionSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle(workout.getWorkoutTitle(for: challenge))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Mark as Complete?", isPresented: $showingCompletionConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Complete") {
                    Task {
                        await completeWorkout()
                    }
                }
            } message: {
                Text("Mark this workout as completed and unlock the next workout.")
            }
        }
    }
    
    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: workoutIcon)
                    .font(.system(size: 40))
                    .foregroundColor(Color(challenge.focusArea.color))
                
                Spacer()
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                }
            }
            
            Text(workout.getWorkoutTitle(for: challenge))
                .font(.title)
                .fontWeight(.bold)
            
            Text("Day \(workout.dayNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var weightSelectorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set Ruck Weight")
                .font(.headline)
            
            // Recommended hint
            if let recommended = workout.weightLbs {
                Button(action: {
                    selectedWorkoutWeight = recommended
                }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(Color("PrimaryMain"))
                        Text("Recommended: \(Int(recommended)) lbs - Tap to Use")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                        Text("Use")
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            
            // Weight display
            Text("\(Int(selectedWorkoutWeight)) lbs")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            
            // Slider
            VStack(spacing: 8) {
                Slider(value: $selectedWorkoutWeight, in: 5...100, step: 5)
                    .accentColor(.blue)
                
                HStack {
                    Text("5 lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100 lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick weight buttons
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Select")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach([10, 15, 20, 25, 30, 35, 40, 45], id: \.self) { weight in
                        Button(action: {
                            selectedWorkoutWeight = Double(weight)
                        }) {
                            Text("\(weight)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedWorkoutWeight == Double(weight) ? .white : .blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedWorkoutWeight == Double(weight) ? Color.blue : Color.blue.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func instructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Instructions", systemImage: "list.bullet.clipboard")
                .font(.headline)
            
            Text(instructions)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var completedSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Workout Completed!")
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            if workout.isRestDay {
                Button(action: {
                    showingCompletionConfirmation = true
                }) {
                    HStack {
                        if isCompleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark as Complete")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isCompleting)
            } else {
                Button(action: {
                    startWorkoutTracking()
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Workout")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Text("Tip: After completing, return here to mark as complete and unlock next workout")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var workoutIcon: String {
        switch workout.workoutType {
        case .ruck:
            return "figure.walk"
        case .rest:
            return "bed.double.fill"
        case .run:
            return "figure.run"
        case .strength:
            return "dumbbell.fill"
        case .cardio:
            return "heart.fill"
        }
    }
    
    private func startWorkoutTracking() {
        workoutManager.startWorkout(weight: selectedWorkoutWeight)
        isPresentingWorkoutFlow = false
    }
    
    private func completeWorkout() async {
        isCompleting = true
        defer { isCompleting = false }
        
        await challengeManager.completeWorkout(workout)
        isPresentingWorkoutFlow = false
        dismiss()
    }
}
