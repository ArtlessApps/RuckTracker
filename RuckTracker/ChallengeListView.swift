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
		ZStack {
			// Background
			Color("BackgroundDark")
				.ignoresSafeArea()
			
			ScrollView(showsIndicators: false) {
				VStack(alignment: .leading, spacing: 0) {
					// Header Section with generous top padding
					VStack(alignment: .leading, spacing: 12) {
						Text("Challenges")
							.font(.system(size: 34, weight: .bold, design: .default))
							.foregroundColor(.white)
						
						Text("Test your limits with focused challenges designed to build specific skills and mental toughness.")
							.font(.system(size: 15, weight: .regular, design: .default))
							.foregroundColor(.white.opacity(0.6))
							.lineSpacing(4)
					}
					.padding(.horizontal, 24)
					.padding(.top, 24)
					.padding(.bottom, 40)
					
					// ENROLLED CHALLENGES SECTION
					if !enrolledChallenges.isEmpty {
						enrolledChallengesSection
					}
					
					// AVAILABLE CHALLENGES SECTION
					availableChallengesSection
				}
			}
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
		VStack(alignment: .leading, spacing: 16) {
			// Section header
			Text("ACTIVE CHALLENGES")
				.font(.system(size: 13, weight: .semibold, design: .default))
				.foregroundColor(.white.opacity(0.5))
				.tracking(1)
				.padding(.horizontal, 24)
			
			// Challenge cards
			ForEach(enrolledChallenges, id: \.0.id) { userChallenge, challenge in
				EnrolledChallengeCard(challenge: challenge, userChallenge: userChallenge) {
					selectedChallenge = challenge
				}
				.padding(.horizontal, 24)
			}
		}
		.padding(.bottom, 32)
	}
    
    // MARK: - Available Section
    
    private var availableChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("AVAILABLE CHALLENGES")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1)
                .padding(.horizontal, 24)
            
            // Challenge cards
            ForEach(availableChallenges) { challenge in
                AvailableChallengeCard(challenge: challenge) {
                    selectedChallenge = challenge
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Public Card Components

struct EnrolledChallengeCard: View {
    let challenge: Challenge
    let userChallenge: UserChallenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 0) {
                // Left side: content
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(challenge.title)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    // Progress info
                    HStack(spacing: 8) {
                        Text("Day \(userChallenge.currentDay)")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(Color("PrimaryMain"))
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("\(Int(userChallenge.completionPercentage))% complete")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    
                    // Description (if available)
                    if let description = challenge.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.72))
                            .lineSpacing(4)
                            .lineLimit(2)
                    }
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Right side: chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
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
        .buttonStyle(ChallengeCardButtonStyle())
    }
}

struct AvailableChallengeCard: View {
    let challenge: Challenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 0) {
                // Left side: content
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(challenge.title)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    // Challenge type and duration
                    HStack(spacing: 8) {
                        Text(challenge.challengeType.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(Color("AccentGreen"))
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                        
                        if challenge.durationDays > 0 {
                            Text("\(challenge.durationDays) days")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.white.opacity(0.72))
                        }
                    }
                    
                    // Description
                    if let description = challenge.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.72))
                            .lineSpacing(4)
                            .lineLimit(2)
                    }
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Right side: duration badge and chevron
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 20) {
                        // Duration badge
                        if challenge.durationDays > 0 {
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
                    }
                    
                    // Chevron indicator
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
        .buttonStyle(ChallengeCardButtonStyle())
    }
}


// MARK: - Preview

struct ChallengeListView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeListView(isPresentingWorkoutFlow: .constant(false))
            .environmentObject(PremiumManager.shared)
    }
}
