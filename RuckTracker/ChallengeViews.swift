//
//  ChallengeViews.swift
//  MARCH
//
//  Views for challenges functionality
//

import SwiftUI


// MARK: - Active Challenge Card

struct ActiveChallengeCard: View {
    let challenge: Challenge
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and duration
            HStack {
                // Dynamic accent circle with icon based on focus area
                ZStack {
                    Circle()
                        .fill(focusAreaColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: challenge.focusArea.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(focusAreaColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textOnLight)
                    
                    if let description = challenge.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Duration badge
                Text("\(challenge.durationDays)d")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.accentWarm.opacity(0.1))
                    )
            }
            
            // Progress section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accentWarm)
                }
                
                // Progress bar with focus area color
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accentWarm.opacity(0.15))
                            .frame(height: 6)
                        
                        // Progress - using muted terracotta color
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.primary)
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.accentWarm.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppColors.accentWarm.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // Helper to determine color based on challenge focus area
    private var focusAreaColor: Color {
        switch challenge.focusArea {
        case .enduranceProgression:
            return AppColors.accentTeal // Dusty Teal
        case .power, .progressiveWeight:
            return AppColors.accentGreen // Sage Green
        case .tacticalMixed:
            return AppColors.textOnLight // Charcoal
        case .recovery:
            return AppColors.primary // Terracotta
        case .distance:
            return AppColors.accentTeal // Dusty Teal
        case .speed, .speedDevelopment:
            return AppColors.accentGreen // Sage Green
        }
    }
}

// MARK: - Available Challenge Card

struct AvailableChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with dynamic accent color based on focus area
            ZStack {
                Circle()
                    .fill(focusAreaColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: challenge.focusArea.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(focusAreaColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(challenge.title)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textOnLight)
                    
                    Spacer()
                }
                
                if let description = challenge.description {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Duration and chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(challenge.durationDays)d")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accentWarm)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.accentWarm.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppColors.accentWarm.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // Helper to determine color based on challenge focus area
    private var focusAreaColor: Color {
        switch challenge.focusArea {
        case .enduranceProgression:
            return AppColors.accentTeal // Dusty Teal
        case .power, .progressiveWeight:
            return AppColors.accentGreen // Sage Green
        case .tacticalMixed:
            return AppColors.textOnLight // Charcoal
        case .recovery:
            return AppColors.primary // Terracotta
        case .distance:
            return AppColors.accentTeal // Dusty Teal
        case .speed, .speedDevelopment:
            return AppColors.accentGreen // Sage Green
        }
    }
}


// MARK: - Challenge Detail View
struct ChallengeDetailView: View {
    let challenge: Challenge
    @Binding var isPresentingWorkoutFlow: Bool
    @EnvironmentObject var challengeService: LocalChallengeService
    @Environment(\.dismiss) private var dismiss
    @State private var showingConflict = false
    @State private var isEnrolled = false
    
    var body: some View {
        Group {
            if isEnrolled {
                // Show workouts if enrolled
                UniversalChallengeView(challenge: challenge, isPresentingWorkoutFlow: $isPresentingWorkoutFlow)
            } else {
                // Show challenge info if not enrolled
                challengeInfoView
            }
        }
        .sheet(isPresented: $showingConflict) {
            if let currentChallenge = challengeService.enrolledChallenge,
               let progress = challengeService.challengeProgress {
                let workoutCount = WorkoutDataManager.shared.getWorkoutCount(forChallengeId: currentChallenge.id)
                
                EnrollmentConflictDialog(
                    type: .challenge,
                    currentName: currentChallenge.title,
                    newName: challenge.title,
                    completedCount: progress.currentDay - 1,
                    totalCount: currentChallenge.durationDays,
                    workoutCount: workoutCount,
                    onSwitch: {
                        // Unenroll from current and proceed with new enrollment
                        challengeService.unenrollFromChallenge()
                        showingConflict = false
                        // Enroll in new challenge directly
                        enrollInChallenge()
                    },
                    onCancel: {
                        showingConflict = false
                    }
                )
            }
        }
        .task {
            // Check if user is already enrolled when view appears
            await checkEnrollmentStatus()
        }
    }
    
    private var challengeInfoView: some View {
        NavigationView {
            ZStack {
                // Background
                AppColors.surface
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(challenge.title)
                                .font(.system(size: 34, weight: .bold, design: .default))
                                .foregroundColor(AppColors.textPrimary)
                            
                            if let description = challenge.description {
                                Text(description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(3)
                            }
                            
                            // Focus Area Badge
                            ChallengeFocusBadge(focusArea: challenge.focusArea)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Challenge Overview Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Challenge Overview")
                                .font(.system(size: 22, weight: .bold, design: .default))
                                .foregroundColor(AppColors.textOnLight)
                            
                            VStack(spacing: 0) {
                                ChallengeOverviewCard(
                                    icon: "calendar",
                                    title: "Duration",
                                    value: "\(challenge.durationDays) days",
                                    iconColor: .blue,
                                    isFirst: true
                                )
                                
                                ChallengeOverviewCard(
                                    icon: "figure.walk",
                                    title: "Type",
                                    value: challenge.challengeType.displayName,
                                    iconColor: AppColors.primary,
                                    isFirst: false,
                                    isLast: true
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Bottom spacing for button
                        Spacer(minLength: 80)
                    }
                    .padding(.vertical, 12)
                }
                
                // Floating CTA Button
                VStack {
                    Spacer()
                    
                    Button(action: {
                        handleEnrollmentTap()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Enroll in Challenge")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(16)
                        .shadow(color: AppColors.shadowBlackLight, radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(
                        LinearGradient(
                            colors: [AppColors.surface.opacity(0), AppColors.surface],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .offset(y: 50)
                    )
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
        }
    }
    
    private func handleEnrollmentTap() {
        // Check for existing enrollment
        if challengeService.enrolledChallenge != nil {
            showingConflict = true
        } else {
            // Skip the enrollment modal and enroll directly
            enrollInChallenge()
        }
    }
    
    private func enrollInChallenge() {
        challengeService.enrollInChallenge(challenge)
        
        Task {
            // Reload enrollment status to trigger view transition
            await checkEnrollmentStatus()
        }
    }
    
    private func checkEnrollmentStatus() async {
        // Check if user is enrolled in this challenge
        isEnrolled = challengeService.isEnrolledIn(challengeId: challenge.id)
    }
}


// MARK: - Challenge Card Components

struct ChallengeOverviewCard: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Title
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            // Value
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textOnLight)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
        .overlay(
            Group {
                if !isLast {
                    Divider()
                        .padding(.leading, 68)
                        .offset(y: 16)
                }
            }
        )
        .cornerRadius(isFirst ? 16 : 0, corners: [.topLeft, .topRight])
        .cornerRadius(isLast ? 16 : 0, corners: [.bottomLeft, .bottomRight])
        .shadow(color: isFirst ? AppColors.shadowBlackSubtle : .clear, radius: 8, x: 0, y: 2)
    }
}

struct ChallengeFocusBadge: View {
    let focusArea: Challenge.FocusArea
    
    var body: some View {
        Text(focusArea.displayName)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(focusAreaColor.opacity(0.2))
            .foregroundColor(focusAreaColor)
            .cornerRadius(8)
    }
    
    private var focusAreaColor: Color {
        switch focusArea {
        case .enduranceProgression:
            return AppColors.accentTeal
        case .power, .progressiveWeight:
            return AppColors.accentGreen
        case .tacticalMixed:
            return AppColors.textOnLight
        case .recovery:
            return AppColors.primary
        case .distance:
            return AppColors.accentTeal
        case .speed, .speedDevelopment:
            return AppColors.accentGreen
        }
    }
}


// MARK: - Helper Functions

private func focusAreaColor(_ focusArea: Challenge.FocusArea) -> Color {
    switch focusArea.color {
    case "red":
        return .red
    case "blue":
        return .blue
    case "green":
        return .green
    case "orange":
        return AppColors.primary
    case "purple":
        return .purple
    default:
        return .blue
    }
}


// MARK: - Preview
struct ChallengeViews_Previews: PreviewProvider {
    static var previews: some View {
        // Preview for ActiveChallengeCard
        ActiveChallengeCard(
            challenge: Challenge(
                id: UUID(),
                title: "Sample Challenge",
                description: "A sample challenge for preview",
                challengeType: .weekly,
                focusArea: .enduranceProgression,
                durationDays: 7,
                weightPercentage: 0.0,
                paceTarget: 12.0,
                distanceFocus: true,
                recoveryFocus: false,
                isSeasonal: false,
                season: nil,
                isActive: true,
                sortOrder: 1,
                createdAt: Date(),
                updatedAt: Date()
            ),
            progress: 0.6
        )
        .padding()
    }
}

