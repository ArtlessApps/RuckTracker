//
//  ChallengeViews.swift
//  RuckTracker
//
//  Views for challenges functionality
//

import SwiftUI

// MARK: - Main Challenges Section
struct ChallengesSection: View {
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
            ChallengeDetailView(challenge: challenge)
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
            // Grid layout for challenges
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(challengeService.challenges) { challenge in
                    ChallengeCardView(challenge: challenge) {
                        selectedChallenge = challenge
                    }
                }
            }
            .padding(.horizontal, 20)
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
                        .foregroundColor(Color(challenge.focusArea.color))
                    
                    Spacer()
                    
                    Text(challenge.focusArea.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(challenge.focusArea.color))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(challenge.focusArea.color).opacity(0.1))
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
    @EnvironmentObject var challengeService: LocalChallengeService
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: challenge.focusArea.iconName)
                                .font(.largeTitle)
                                .foregroundColor(Color(challenge.focusArea.color))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(challenge.focusArea.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(Color(challenge.focusArea.color))
                            }
                            
                            Spacer()
                        }
                        
                        if let description = challenge.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Challenge details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Challenge Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            DetailRowView(
                                icon: "calendar",
                                title: "Duration",
                                value: "\(challenge.durationDays) days"
                            )
                            
                            if let weightPercentage = challenge.weightPercentage {
                                DetailRowView(
                                    icon: "scalemass.fill",
                                    title: "Weight Target",
                                    value: "\(Int(weightPercentage))% of body weight"
                                )
                            }
                            
                            if let paceTarget = challenge.paceTarget {
                                DetailRowView(
                                    icon: "speedometer",
                                    title: "Pace Target",
                                    value: "\(String(format: "%.1f", paceTarget)) min/mile"
                                )
                            }
                            
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
                        showingEnrollment = true
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingEnrollment) {
            LocalChallengeEnrollmentView(challenge: challenge)
                .environmentObject(challengeService)
        }
    }
}

// MARK: - Challenge Enrollment View
struct LocalChallengeEnrollmentView: View {
    let challenge: Challenge
    @EnvironmentObject var challengeService: LocalChallengeService
    @Environment(\.dismiss) private var dismiss
    @State private var startingWeight: Double = 150.0
    @State private var isEnrolling = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: challenge.focusArea.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(Color(challenge.focusArea.color))
                    
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
                
                // Weight input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Starting Weight")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Weight", value: $startingWeight, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        
                        Text("lbs")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("This helps us calculate your target weight for the challenge.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                
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
                .disabled(isEnrolling || startingWeight <= 0)
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
        
        challengeService.enrollInChallenge(challenge, startingWeight: startingWeight)
        
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


// MARK: - Preview
struct ChallengeViews_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesSection()
            .environmentObject(PremiumManager())
    }
}
