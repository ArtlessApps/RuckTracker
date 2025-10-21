//
//  ChallengeViews.swift
//  RuckTracker
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
                        .foregroundColor(Color("BackgroundDark"))
                    
                    if let description = challenge.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color("TextSecondary"))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Duration badge
                Text("\(challenge.durationDays)d")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("WarmGray").opacity(0.1))
                    )
            }
            
            // Progress section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color("WarmGray"))
                }
                
                // Progress bar with focus area color
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("WarmGray").opacity(0.15))
                            .frame(height: 6)
                        
                        // Progress - using muted terracotta color
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("PrimaryMain"))
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color("WarmGray").opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color("WarmGray").opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // Helper to determine color based on challenge focus area
    private var focusAreaColor: Color {
        switch challenge.focusArea {
        case .enduranceProgression:
            return Color("AccentTeal") // Dusty Teal
        case .power, .progressiveWeight:
            return Color("AccentGreen") // Sage Green
        case .tacticalMixed:
            return Color("BackgroundDark") // Charcoal
        case .recovery:
            return Color("PrimaryMain") // Terracotta
        case .distance:
            return Color("AccentTeal") // Dusty Teal
        case .speed, .speedDevelopment:
            return Color("AccentGreen") // Sage Green
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
                        .foregroundColor(Color("BackgroundDark"))
                    
                    Spacer()
                }
                
                if let description = challenge.description {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Duration and chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(challenge.durationDays)d")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color("WarmGray"))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color("WarmGray").opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color("WarmGray").opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // Helper to determine color based on challenge focus area
    private var focusAreaColor: Color {
        switch challenge.focusArea {
        case .enduranceProgression:
            return Color("AccentTeal") // Dusty Teal
        case .power, .progressiveWeight:
            return Color("AccentGreen") // Sage Green
        case .tacticalMixed:
            return Color("BackgroundDark") // Charcoal
        case .recovery:
            return Color("PrimaryMain") // Terracotta
        case .distance:
            return Color("AccentTeal") // Dusty Teal
        case .speed, .speedDevelopment:
            return Color("AccentGreen") // Sage Green
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: challenge.focusArea.iconName)
                                .font(.largeTitle)
                                .foregroundColor(focusAreaColor(challenge.focusArea))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(challenge.focusArea.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(focusAreaColor(challenge.focusArea))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        if let description = challenge.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    // Challenge Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Challenge Details")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            DetailRowView(
                                icon: "calendar",
                                title: "Duration",
                                value: "\(challenge.durationDays) days"
                            )
                            
                            DetailRowView(
                                icon: "figure.walk",
                                title: "Type",
                                value: challenge.challengeType.displayName
                            )
                            
                            DetailRowView(
                                icon: challenge.distanceFocus ? "location.fill" : "location",
                                title: "Distance Focus",
                                value: challenge.distanceFocus ? "Yes" : "No"
                            )
                            
                            DetailRowView(
                                icon: challenge.recoveryFocus ? "heart.fill" : "heart",
                                title: "Recovery Focus",
                                value: challenge.recoveryFocus ? "Yes" : "No"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enroll") {
                        handleEnrollmentTap()
                    }
                    .fontWeight(.semibold)
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


// MARK: - Detail Row View
struct DetailRowView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
        return Color("PrimaryMain")
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
