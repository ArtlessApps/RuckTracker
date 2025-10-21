//
//  ChallengeViews.swift
//  RuckTracker
//
//  Views for challenges functionality
//

import SwiftUI

// MARK: - Main Challenges Section
struct ChallengesSection: View {
    @Binding var isPresentingWorkoutFlow: Bool
    @StateObject private var challengeService = LocalChallengeService.shared
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var selectedChallenge: Challenge?
    
    var body: some View {
        ZStack {
            // Background
            Color("BackgroundDark")
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Weekly Challenges")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !premiumManager.isPremiumUser {
                        PremiumBadge(size: .small)
                    }
                }
                
                    Text("7-day focused challenges designed to build specific skills and push your limits.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if challengeService.isLoading {
                    ProgressView("Loading challenges...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    challengesView
                }
            }
            }
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(challenge: challenge, isPresentingWorkoutFlow: $isPresentingWorkoutFlow)
                .environmentObject(challengeService)
                .environmentObject(premiumManager)
        }
        .onAppear {
            challengeService.loadChallenges()
        }
    }
    
    @ViewBuilder
    private var challengesView: some View {
        if challengeService.challenges.isEmpty {
            EmptyStateView(
                icon: "target",
                title: "No Challenges Available",
                description: "Check back later for new challenges to test your skills."
            )
            .padding()
        } else {
            VStack(spacing: 16) {
                // ENROLLED CHALLENGES SECTION (NEW)
                if !enrolledChallenges.isEmpty {
                    enrolledChallengesSection
                }
                
                // AVAILABLE CHALLENGES SECTION
                availableChallengesSection
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var enrolledChallenges: [(UserChallenge, Challenge)] {
        challengeService.userChallenges
            .filter { $0.isActive }
            .compactMap { userChallenge in
                if let challenge = challengeService.challenges.first(where: { $0.id == userChallenge.challengeId }) {
                    return (userChallenge, challenge)
                }
                return nil
            }
            .sorted { $0.0.startDate > $1.0.startDate } // Most recent first
    }
    
    private var availableChallenges: [Challenge] {
        let enrolledIds = Set(challengeService.userChallenges.map { $0.challengeId })
        return challengeService.challenges
            .filter { !enrolledIds.contains($0.id) && $0.isActive }
            .sorted { challenge1, challenge2 in
                // Sort by focus area, then alphabetically
                if challenge1.focusArea.rawValue != challenge2.focusArea.rawValue {
                    return challenge1.focusArea.rawValue < challenge2.focusArea.rawValue
                }
                return challenge1.title < challenge2.title
            }
    }
    
    // MARK: - Enrolled Section
    
    private var enrolledChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 24)
            
            VStack(spacing: 20) {
                ForEach(enrolledChallenges, id: \.0.id) { userChallenge, challenge in
                    ChallengeCardView(challenge: challenge) {
                        selectedChallenge = challenge
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Divider()
                .padding(.vertical, 8)
        }
    }
    
    // MARK: - Available Section
    
    private var availableChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Challenges")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 24)
            
            VStack(spacing: 20) {
                ForEach(availableChallenges) { challenge in
                    ChallengeCardView(challenge: challenge) {
                        selectedChallenge = challenge
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Challenge Card View
struct ChallengeCardView: View {
    let challenge: Challenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Accent bar on left - bold with glow
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [focusAreaColor(challenge.focusArea), focusAreaColor(challenge.focusArea).opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6)
                    .shadow(color: focusAreaColor(challenge.focusArea).opacity(0.5), radius: 6, x: 3, y: 0)
                
                // Content
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(challenge.title)
                            .font(.system(size: 19, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                        
                        Text(challenge.description ?? "")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.72))
                            .lineSpacing(4)
                            .lineLimit(3)
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    // Right side: duration badge and chevron with perfect vertical centering
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .trailing, spacing: 20) {
                            // Duration badge - softer brightness
                            Text("\(challenge.durationDays)d")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.black.opacity(0.85))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.85))
                                )
                        }
                        
                        // Chevron indicator - perfectly centered vertically
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 16)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.vertical, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.11))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(0.2),
                                .white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(ProgramCardButtonStyle())
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
        ChallengesSection(isPresentingWorkoutFlow: .constant(false))
            .environmentObject(PremiumManager())
    }
}
