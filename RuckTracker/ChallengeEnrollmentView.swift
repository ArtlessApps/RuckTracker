//
//  ChallengeEnrollmentView.swift
//  MARCH
//
//  Universal enrollment view for any challenge type with weight selection
//

import SwiftUI

struct ChallengeEnrollmentView: View {
    let challenge: Challenge
    let challengeManager: ChallengeManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEnrolling = false
    @State private var enrollmentError: String?
    
    // Focus color computed property
    private var focusColor: Color {
        switch challenge.focusArea.color {
        case "red": return AppColors.accentWarm
        case "blue": return AppColors.accentTeal
        case "green": return AppColors.accentGreen
        case "orange": return AppColors.primary
        case "purple": return AppColors.primary
        default: return AppColors.primary
        }
    }
    
    // Weight selection removed
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView {
                    VStack(spacing: 24) {
                        // Challenge Info Header
                        challengeHeaderView
                        
                        // Weight selection removed
                        
                        // Challenge Preview
                        challengePreviewView
                        
                        // Enrollment Button
                        enrollmentButtonView
                        
                        // Extra padding to ensure button is visible
                        Color.clear.frame(height: 50)
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height)
                    }
                }
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
        .onAppear { }
    }
    
    private var challengeHeaderView: some View {
        VStack(spacing: 12) {
            Image(systemName: challenge.focusArea.iconName)
                .font(.system(size: 50))
                .foregroundColor(focusColor)
            
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
    
    // Weight selection view removed
    
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
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle")
                        Text("Enroll in Challenge")
                    }
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isEnrolling ? 
                            Color.gray : 
                            focusColor
                        )
                        .shadow(color: focusColor.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .disabled(isEnrolling)
            .buttonStyle(.plain)
            
            // Note about weight removed
        }
    }
    
    private func enrollInChallenge() {
        print("🎯 Enroll button tapped - starting enrollment process")
        Task {
            isEnrolling = true
            enrollmentError = nil
            
            do {
        print("📝 Attempting to enroll in challenge")
        try await challengeManager.enrollInChallenge()
                
                print("✅ Enrollment successful - enrollment added to service")
                // The enrollment is already added to the service in ChallengeManager
                
                print("🔄 Dismissing enrollment view")
                // Enrollment successful
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Enrollment failed: \(error)")
                await MainActor.run {
                    enrollmentError = "Failed to enroll: \(error.localizedDescription)"
                    isEnrolling = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

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
