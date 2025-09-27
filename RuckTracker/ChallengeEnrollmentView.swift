//
//  ChallengeEnrollmentView.swift
//  RuckTracker
//
//  Universal enrollment view for any challenge type with weight selection
//

import SwiftUI

struct ChallengeEnrollmentView: View {
    let challenge: StackChallenge
    let challengeManager: ChallengeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWeight: Double = 20.0
    @State private var isEnrolling = false
    @State private var enrollmentError: String?
    
    // Weight range based on challenge type
    private var weightRange: ClosedRange<Double> {
        switch challenge.focusArea {
        case .recovery:
            return 10.0...30.0 // Light weights for recovery
        case .speed, .speedDevelopment:
            return 15.0...35.0 // Moderate weights for speed
        case .distance, .enduranceProgression:
            return 20.0...45.0 // Standard range for distance
        case .power, .progressiveWeight:
            return 25.0...60.0 // Heavy weights for power
        case .tacticalMixed:
            return 30.0...50.0 // Tactical standard weights
        }
    }
    
    private var recommendedWeight: Double {
        switch challenge.focusArea {
        case .recovery:
            return 15.0
        case .speed, .speedDevelopment:
            return 25.0
        case .distance, .enduranceProgression:
            return 30.0
        case .power, .progressiveWeight:
            return 40.0
        case .tacticalMixed:
            return 35.0
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Challenge Info Header
                    challengeHeaderView
                    
                    // Weight Selection
                    weightSelectionView
                    
                    // Challenge Preview
                    challengePreviewView
                    
                    // Enrollment Button
                    enrollmentButtonView
                }
                .padding()
            }
            .navigationTitle("Enroll in Challenge")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedWeight = recommendedWeight
        }
    }
    
    private var challengeHeaderView: some View {
        VStack(spacing: 12) {
            Image(systemName: challenge.focusArea.iconName)
                .font(.system(size: 50))
                .foregroundColor(Color(challenge.focusArea.color))
            
            Text(challenge.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if let description = challenge.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Challenge stats
            HStack(spacing: 20) {
                StatView(
                    icon: "calendar",
                    title: "Duration",
                    value: "\(challenge.durationDays) days"
                )
                
                StatView(
                    icon: challenge.focusArea.iconName,
                    title: "Focus",
                    value: challenge.focusArea.displayName
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var weightSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Your Starting Weight")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Choose a ruck weight that challenges you while maintaining proper form throughout the challenge.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Weight Slider
            VStack(spacing: 12) {
                HStack {
                    Text("\(Int(weightRange.lowerBound)) lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(selectedWeight)) lbs")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(challenge.focusArea.color))
                    
                    Spacer()
                    
                    Text("\(Int(weightRange.upperBound)) lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $selectedWeight,
                    in: weightRange,
                    step: 5.0
                )
                .accentColor(Color(challenge.focusArea.color))
            }
            
            // Weight Recommendation
            if abs(selectedWeight - recommendedWeight) < 2.5 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Recommended weight for \(challenge.focusArea.displayName.lowercased()) training")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else if selectedWeight < recommendedWeight - 5 {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Light weight - good for building endurance")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            } else if selectedWeight > recommendedWeight + 5 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Heavy weight - ensure proper form")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var challengePreviewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to Expect")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ExpectationRow(
                    icon: "target",
                    title: "Progressive Training",
                    description: "Workouts designed to build your \(challenge.focusArea.displayName.lowercased()) capabilities"
                )
                
                ExpectationRow(
                    icon: "calendar.badge.checkmark",
                    title: "Daily Guidance",
                    description: "Clear instructions for each day's training session"
                )
                
                ExpectationRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress Tracking",
                    description: "Monitor your completion and performance throughout"
                )
                
                if challenge.focusArea == .recovery {
                    ExpectationRow(
                        icon: "heart.fill",
                        title: "Active Recovery",
                        description: "Light movement to aid recovery and maintain fitness"
                    )
                } else {
                    ExpectationRow(
                        icon: "figure.strengthtraining.traditional",
                        title: "Structured Rest",
                        description: "Built-in recovery days to optimize your training"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var enrollmentButtonView: some View {
        VStack(spacing: 12) {
            if let error = enrollmentError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
            
            Button(action: enrollInChallenge) {
                HStack {
                    if isEnrolling {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "checkmark.circle")
                        Text("Start \(challenge.title)")
                    }
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isEnrolling ? 
                            Color.gray : 
                            Color(challenge.focusArea.color)
                        )
                )
            }
            .disabled(isEnrolling)
            .buttonStyle(.plain)
            
            Text("You can adjust your weight anytime during the challenge")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func enrollInChallenge() {
        Task {
            isEnrolling = true
            enrollmentError = nil
            
            do {
                try await challengeManager.enrollInChallenge(weightLbs: selectedWeight)
                
                // Enrollment successful
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    enrollmentError = "Failed to enroll: \(error.localizedDescription)"
                    isEnrolling = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct ExpectationRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
