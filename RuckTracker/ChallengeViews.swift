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
    @State private var showingEnrollment = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Weekly Challenges")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if !premiumManager.isPremiumUser {
                        PremiumBadge(size: .small)
                    }
                }
                
                Text("7-day focused challenges designed to build specific skills and push your limits.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(challenge: challenge, isPresentingWorkoutFlow: $isPresentingWorkoutFlow)
                .environmentObject(challengeService)
        }
        .sheet(isPresented: $showingEnrollment) {
            if let challenge = selectedChallenge {
                LocalChallengeEnrollmentView(challenge: challenge)
                    .environmentObject(challengeService)
            }
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
            ScrollView {
                VStack(spacing: 16) {
                    // ENROLLED CHALLENGES SECTION (NEW)
                    if !enrolledChallenges.isEmpty {
                        enrolledChallengesSection
                    }
                    
                    // AVAILABLE CHALLENGES SECTION
                    availableChallengesSection
                }
                .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Active")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            ForEach(enrolledChallenges, id: \.0.id) { userChallenge, challenge in
                EnrolledChallengeCard(
                    challenge: challenge,
                    userChallenge: userChallenge
                ) {
                    selectedChallenge = challenge
                }
                .padding(.horizontal)
            }
            
            Divider()
                .padding(.vertical, 8)
        }
    }
    
    // MARK: - Available Section
    
    private var availableChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Challenges")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(availableChallenges) { challenge in
                    ChallengeCardView(challenge: challenge) {
                        selectedChallenge = challenge
                    }
                }
            }
        }
    }
}

// MARK: - Challenge Card View
struct ChallengeCardView: View {
    let challenge: Challenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and focus area
                HStack {
                    Image(systemName: challenge.focusArea.iconName)
                        .font(.title2)
                        .foregroundColor(focusAreaColor(challenge.focusArea))
                    
                    Spacer()
                    
                    Text(challenge.focusArea.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(focusAreaColor(challenge.focusArea))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(focusAreaColor(challenge.focusArea).opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Title and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let description = challenge.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Challenge details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(challenge.durationDays) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let weightPercentage = challenge.weightPercentage {
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(weightPercentage))% body weight")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let paceTarget = challenge.paceTarget {
                        HStack {
                            Image(systemName: "speedometer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", paceTarget)) min/mile")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Challenge Detail View
struct ChallengeDetailView: View {
    let challenge: Challenge
    @Binding var isPresentingWorkoutFlow: Bool
    @EnvironmentObject var challengeService: LocalChallengeService
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
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
        .sheet(isPresented: $showingEnrollment, onDismiss: {
            // Re-check enrollment status when sheet dismisses
            Task {
                await checkEnrollmentStatus()
            }
        }) {
            LocalChallengeEnrollmentView(challenge: challenge)
                .environmentObject(challengeService)
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
                        showingEnrollment = true
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
            showingEnrollment = true
        }
    }
    
    private func checkEnrollmentStatus() async {
        // Check if user is enrolled in this challenge
        isEnrolled = challengeService.isEnrolledIn(challengeId: challenge.id)
    }
}

// MARK: - Challenge Enrollment View
struct LocalChallengeEnrollmentView: View {
    let challenge: Challenge
    @EnvironmentObject var challengeService: LocalChallengeService
    @Environment(\.dismiss) private var dismiss
    // startingWeight removed
    @State private var isEnrolling = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: challenge.focusArea.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(focusAreaColor(challenge.focusArea))
                    
                    Text("Enroll in \(challenge.title)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Ready to push your limits? This \(challenge.durationDays)-day challenge will test your \(challenge.focusArea.displayName.lowercased()) skills.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Weight input removed
                
                Spacer()
                
                // Enroll button
                Button(action: enrollInChallenge) {
                    HStack {
                        if isEnrolling {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isEnrolling ? "Enrolling..." : "Start Challenge")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isEnrolling)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Enroll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func enrollInChallenge() {
        isEnrolling = true
        
        challengeService.enrollInChallenge(challenge)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isEnrolling = false
            dismiss()
        }
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
        return .orange
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
