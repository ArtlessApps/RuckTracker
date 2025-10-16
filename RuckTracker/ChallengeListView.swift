//
//  ChallengeListView.swift
//  RuckTracker
//
//  Enhanced challenge list view with enrolled challenges sorted to the top
//

import SwiftUI

struct ChallengeListView: View {
    @Binding var isPresentingWorkoutFlow: Bool
    @StateObject private var challengeService = LocalChallengeService.shared
    @State private var selectedChallenge: Challenge?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text("Challenges")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // ENROLLED CHALLENGES SECTION (NEW)
                if !enrolledChallenges.isEmpty {
                    enrolledChallengesSection
                }
                
                // AVAILABLE CHALLENGES SECTION
                availableChallengesSection
            }
            .padding(.vertical)
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(challenge: challenge, isPresentingWorkoutFlow: $isPresentingWorkoutFlow)
                .environmentObject(challengeService)
        }
        .onAppear {
            challengeService.loadChallenges()
            challengeService.loadUserChallenges()
            challengeService.loadEnrollmentStatus()
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
                .padding(.horizontal)
            
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
                .padding(.horizontal)
        }
    }
    
    // MARK: - Available Section
    
    private var availableChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Challenges")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ForEach(availableChallenges) { challenge in
                AvailableChallengeCard(challenge: challenge) {
                    selectedChallenge = challenge
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Enrolled Challenge Card

struct EnrolledChallengeCard: View {
    let challenge: Challenge
    let userChallenge: UserChallenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and active status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let description = challenge.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Active status indicator
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                
                // Progress information
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Day \(userChallenge.currentDay)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("\(Int(userChallenge.currentWeightLbs)) lbs")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryMain"))
                    }
                    
                    // Progress bar
                    ProgressView(value: userChallenge.completionPercentage / 100.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(y: 1.5)
                }
                .padding(.top, 4)
                
                // Challenge details
                HStack {
                    Label(challenge.focusArea.displayName, systemImage: challenge.focusArea.iconName)
                        .font(.caption2)
                        .foregroundColor(focusAreaColor(challenge.focusArea))
                    
                    Spacer()
                    
                    if challenge.durationDays > 0 {
                        Text("\(challenge.durationDays) days")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ongoing")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func focusAreaColor(_ focusArea: Challenge.FocusArea) -> Color {
        switch focusArea {
        case .power, .progressiveWeight: return Color("PrimaryMedium")
        case .speed, .speedDevelopment: return .blue
        case .distance, .enduranceProgression: return Color("AccentGreen")
        case .recovery: return Color("PrimaryMain")
        case .tacticalMixed: return .purple
        }
    }
}

// MARK: - Available Challenge Card

struct AvailableChallengeCard: View {
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
                        Text(challenge.challengeType.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if challenge.durationDays > 0 {
                            Text("\(challenge.durationDays) days")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Ongoing")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Additional challenge info
                    if let weightPercentage = challenge.weightPercentage {
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .font(.caption2)
                                .foregroundColor(Color("PrimaryMain"))
                            Text("\(Int(weightPercentage))% body weight")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let paceTarget = challenge.paceTarget {
                        HStack {
                            Image(systemName: "speedometer")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(Int(paceTarget)) min/mile target")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func focusAreaColor(_ focusArea: Challenge.FocusArea) -> Color {
        switch focusArea {
        case .power, .progressiveWeight: return Color("PrimaryMedium")
        case .speed, .speedDevelopment: return .blue
        case .distance, .enduranceProgression: return Color("AccentGreen")
        case .recovery: return Color("PrimaryMain")
        case .tacticalMixed: return .purple
        }
    }
}

// MARK: - Preview

struct ChallengeListView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeListView(isPresentingWorkoutFlow: .constant(false))
            .environmentObject(PremiumManager.shared)
    }
}
