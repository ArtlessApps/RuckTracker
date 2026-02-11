//
//  UniversalChallengeView.swift
//  MARCH
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
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
    @State private var showingLeaveWarning = false
    @State private var selectedWorkout: ChallengeWorkout?
    @State private var selectedWorkoutWeight: Double = UserSettings.shared.defaultRuckWeight
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient.ignoresSafeArea()
                
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
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingEnrollment) {
            ChallengeEnrollmentView(challenge: challenge, challengeManager: challengeManager)
        }
        .sheet(item: $selectedWorkout) { workout in
            if !workout.isRestDay && !challengeManager.isWorkoutCompleted(workout.id) && !challengeManager.isWorkoutLocked(workout) {
                // Ruck/active workout ready to start → use unified weight selector
                WorkoutWeightSelector(
                    selectedWeight: $selectedWorkoutWeight,
                    isPresented: Binding(
                        get: { selectedWorkout != nil },
                        set: { if !$0 { selectedWorkout = nil } }
                    ),
                    recommendedWeight: workout.weightLbs,
                    context: workout.getWorkoutTitle(for: challenge),
                    subtitle: "Day \(workout.dayNumber)",
                    instructions: workout.instructions,
                    onStart: {
                        startChallengeWorkout(workout)
                    }
                )
                .onAppear {
                    selectedWorkoutWeight = workout.weightLbs ?? UserSettings.shared.defaultRuckWeight
                }
            } else {
                // Rest day, completed, or locked → show detail view
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
    
    private func startChallengeWorkout(_ workout: ChallengeWorkout) {
        // Set the weight in workout manager
        workoutManager.ruckWeight = selectedWorkoutWeight
        
        // Start the workout
        workoutManager.startWorkout(weight: selectedWorkoutWeight)
        
        // Trigger the workout flow presentation
        isPresentingWorkoutFlow = true
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
                .fill(AppColors.surface)
                .shadow(color: AppColors.shadowBlackSubtle, radius: 8, x: 0, y: 2)
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
                        .foregroundColor(AppColors.textSecondary)
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
        .foregroundColor(AppColors.textPrimary)
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(challenge.title)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\(challengeManager.completedWorkoutCount) of \(challengeManager.totalWorkoutCount) workouts")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(AppColors.accentWarm.opacity(0.2), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: challengeManager.progressPercentage)
                        .stroke(Color(challenge.focusArea.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: challengeManager.progressPercentage)
                    
                    Text("\(Int(challengeManager.progressPercentage * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textOnLight)
                }
            }
        }
    }
    
    private var enrollmentPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: challenge.focusArea.iconName)
                .font(.system(size: 40))
                .foregroundColor(AppColors.primary)
            
            Text("Ready to Start?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enroll in this \(challenge.durationDays)-day challenge to begin tracking your progress.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
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
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.primaryGradient)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
                .shadow(color: AppColors.textOnLight.opacity(0.1), radius: 2, x: 0, y: 1)
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
                    .foregroundColor(isLocked ? AppColors.textSecondary.opacity(0.5) : AppColors.textOnLight)
                
                Text(workout.displaySubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isLocked ? AppColors.textSecondary.opacity(0.4) : AppColors.textSecondary)
                
                if let instructions = workout.instructions?.prefix(50) {
                    Text(String(instructions) + "...")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Status Icon
            if !isCompleted && !isLocked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isLocked ? AppColors.surface.opacity(0.6) : AppColors.surface)
                .shadow(
                    color: isLocked ? AppColors.textOnLight.opacity(0.02) : AppColors.textOnLight.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .opacity(isLocked ? 0.7 : 1.0)
    }
    
    private var statusColor: Color {
        if isCompleted {
            return AppColors.accentGreen
        } else if isLocked {
            return AppColors.textSecondary
        } else if workout.isRestDay {
            return AppColors.accentTeal
        } else {
            return AppColors.primary
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
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Challenge Workout Detail View (Rest Day / Completed States)
struct ChallengeWorkoutDetailView: View {
    let workout: ChallengeWorkout
    let challenge: Challenge
    @ObservedObject var challengeManager: ChallengeManager
    @Binding var isPresentingWorkoutFlow: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompletionConfirmation = false
    @State private var isCompleting = false
    
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
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Top section with context
                    VStack(spacing: 8) {
                        Text(workout.getWorkoutTitle(for: challenge))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Day \(workout.dayNumber)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.bottom, 40)
                    
                    // Content based on state
                    if isCompleted {
                        completedSection
                    } else {
                        restDaySection
                    }
                    
                    Spacer()
                        .frame(minHeight: 20)
                    
                    // Instructions at bottom
                    if let instructions = workout.instructions {
                        instructionsSection(instructions)
                    }
                    
                    Spacer()
                    
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
                    .foregroundColor(AppColors.primary)
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
    
    // MARK: - Subviews
    
    private var completedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.accentGreen)
            
            Text("Completed")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Great work!")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 40)
    }
    
    private var restDaySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.accentTeal)
            
            Text("Rest Day")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Recovery is essential")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 40)
    }
    
    private func instructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.primary)
                
                Text("Instructions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(instructions)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surfaceAlt.opacity(0.5))
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
                    .foregroundColor(AppColors.accentGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.accentGreen.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            } else if !isLocked && workout.isRestDay {
                // Rest day - mark complete
                Button(action: {
                    showingCompletionConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16))
                        Text("Mark Complete")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.primaryGradient)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
    
    // MARK: - Methods
    
    private func completeWorkout() async {
        isCompleting = true
        defer { isCompleting = false }
        
        await challengeManager.completeWorkout(workout)
        isPresentingWorkoutFlow = false
        dismiss()
    }
}
