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
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if challengeManager.isLoading {
                    loadingView
                } else {
                    challengeListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingLeaveWarning = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color("TextSecondary"))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("PrimaryMain"))
                }
            }
        }
        .sheet(isPresented: $showingEnrollment) {
            ChallengeEnrollmentView(challenge: challenge, challengeManager: challengeManager)
        }
        .sheet(item: $selectedWorkout) { workout in
            ChallengeWorkoutDetailView(
                workout: workout,
                challenge: challenge,
                challengeManager: challengeManager,
                isPresentingWorkoutFlow: $isPresentingWorkoutFlow
            )
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
    
    // MARK: - Subviews
    
    private var challengeListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Progress Header Card
                progressHeader
                
                // Challenge Workout Cards
                LazyVStack(spacing: 12) {
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
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .padding(.vertical, 12)
        }
    }
    
    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            if challengeManager.enrollment != nil {
                progressSection
            } else {
                enrollmentPrompt
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading challenge...")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color("TextSecondary"))
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
        }
        .padding()
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(challenge.title)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(Color("BackgroundDark"))
                    
                    Text("\(challengeManager.completedWorkoutCount) of \(challengeManager.totalWorkoutCount) workouts")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                }
                
                Spacer()
                
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color("WarmGray").opacity(0.2), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: challengeManager.progressPercentage)
                        .stroke(Color(challenge.focusArea.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: challengeManager.progressPercentage)
                    
                    Text("\(Int(challengeManager.progressPercentage * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color("BackgroundDark"))
                }
            }
        }
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

// MARK: - Universal Workout Row View (Updated Card Style)
struct UniversalWorkoutRowView: View {
    let workout: ChallengeWorkout
    let challenge: Challenge
    let index: Int
    let isCompleted: Bool
    let isLocked: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Numbered Badge (Icon-less)
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(statusColor)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(statusColor)
                } else {
                    Text("\(index)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(statusColor)
                }
            }
            
            // Workout Details
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.getWorkoutTitle(for: challenge))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isLocked ? Color("TextSecondary").opacity(0.5) : Color("BackgroundDark"))
                
                Text(workout.displaySubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isLocked ? Color("TextSecondary").opacity(0.4) : Color("TextSecondary"))
                
                if let instructions = workout.instructions?.prefix(50) {
                    Text(String(instructions) + "...")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color("TextSecondary").opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Status Icon
            if !isCompleted && !isLocked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isLocked ? Color.white.opacity(0.6) : Color.white)
                .shadow(
                    color: isLocked ? Color.black.opacity(0.02) : Color.black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .opacity(isLocked ? 0.7 : 1.0)
    }
    
    private var statusColor: Color {
        if isCompleted {
            return Color("AccentGreen")
        } else if isLocked {
            return Color("TextSecondary")
        } else if workout.isRestDay {
            return Color("AccentTeal")
        } else {
            return Color("PrimaryMain")
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
            ZStack {
                // Clean white background
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top section with context
                    VStack(spacing: 8) {
                        Text(workout.getWorkoutTitle(for: challenge))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color("BackgroundDark"))
                        
                        Text("Day \(workout.dayNumber)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                    
                    // Weight Selector (only for ruck workouts)
                    if !workout.isRestDay {
                        weightSelectorSection
                    } else {
                        restDaySection
                    }
                    
                    Spacer()
                    
                    // Instructions at bottom
                    if let instructions = workout.instructions {
                        instructionsSection(instructions)
                    }
                    
                    // Action Buttons
                    actionButtons
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("PrimaryMain"))
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
    
    
    private var weightSelectorSection: some View {
        VStack(spacing: 0) {
            Text("Set Ruck Weight")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("TextSecondary"))
                .padding(.bottom, 20)
            
            // HERO - Selected Weight
            (Text("\(Int(selectedWorkoutWeight))")
                .font(.system(size: 100, weight: .medium))
             + Text(" lbs")
                .font(.system(size: 36, weight: .regular)))
                .foregroundColor(Color("BackgroundDark"))
                .padding(.bottom, 60)
            
            // Slider
            VStack(spacing: 16) {
                Slider(value: $selectedWorkoutWeight, in: 0...100, step: 1)
                    .tint(Color("BackgroundDark"))
                
                HStack {
                    Text("0 lbs")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                    
                    Spacer()
                    
                    Text("100 lbs")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var restDaySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 60))
                .foregroundColor(Color("AccentTeal"))
            
            Text("Rest Day")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(Color("BackgroundDark"))
            
            Text("Recovery is essential")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color("TextSecondary"))
        }
        .padding(.vertical, 40)
    }
    
    private func instructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(Color("PrimaryMain"))
                
                Text("Instructions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("BackgroundDark"))
            }
            
            Text(instructions)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("TextSecondary"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("AccentTeal").opacity(0.08))
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            if isCompleted {
                // Completed state - just close button
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Completed")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color("AccentGreen"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("AccentGreen").opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            } else if !isLocked {
                // Cancel Button
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color("BackgroundDark"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("BackgroundDark").opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                
                // Start Button
                Button(action: {
                    startWorkout()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text("Start Workout")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("PrimaryMain"))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
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
    
    private func startWorkout() {
        // Set the weight in workout manager
        workoutManager.ruckWeight = selectedWorkoutWeight
        
        // Start the workout
        workoutManager.startWorkout(weight: selectedWorkoutWeight)
        
        // Trigger the workout flow presentation
        isPresentingWorkoutFlow = true
        
        // Dismiss this view
        dismiss()
    }
    
    private func completeWorkout() async {
        isCompleting = true
        defer { isCompleting = false }
        
        await challengeManager.completeWorkout(workout)
        isPresentingWorkoutFlow = false
        dismiss()
    }
}
