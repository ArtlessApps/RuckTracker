import SwiftUI
import Foundation
import Combine

// TrainingProgramsView.swift
// Premium training programs view with clean, minimal aesthetic
import SwiftUI

struct TrainingProgramsView: View {
    @Binding var isPresentingWorkoutFlow: Bool
    @EnvironmentObject var premiumManager: PremiumManager
    @StateObject private var programService = LocalProgramService.shared
    @State private var selectedProgram: Program?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Training Programs")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color("BackgroundDark"))
                        
                        Text("Structured training plans to build strength, endurance, and consistent rucking habits.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color("TextSecondary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                    
                    // Programs List
                    if programService.isLoading {
                        ProgressView()
                            .padding()
                    } else if programService.programs.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 0) {
                            // Active Programs Section
                            if !enrolledPrograms.isEmpty {
                                activeProgramsSection
                                
                                Spacer()
                                    .frame(height: 40)
                            }
                            
                            // Available Programs Section
                            availableProgramsSection
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedProgram) { program in
            ProgramDetailView(
                program: program,
                isPresentingWorkoutFlow: $isPresentingWorkoutFlow,
                onDismiss: {
                    selectedProgram = nil
                }
            )
            .environmentObject(programService)
        }
        .onAppear {
            programService.loadPrograms()
            programService.loadEnrollmentStatus()
            programService.loadUserPrograms()
        }
    }
    
    // MARK: - Computed Properties
    
    private var enrolledPrograms: [(UserProgram, Program)] {
        programService.userPrograms
            .filter { $0.isActive }
            .compactMap { userProgram in
                if let program = programService.programs.first(where: { $0.id == userProgram.programId }) {
                    return (userProgram, program)
                }
                return nil
            }
    }
    
    private var availablePrograms: [Program] {
        let enrolledIds = Set(enrolledPrograms.map { $0.1.id })
        return programService.programs.filter { !enrolledIds.contains($0.id) }
    }
    
    // MARK: - Active Programs Section
    
    private var activeProgramsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Programs")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("TextSecondary"))
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                ForEach(enrolledPrograms, id: \.0.id) { userProgram, program in
                    ProgramRowView(
                        program: program,
                        isActive: true,
                        progress: calculateProgress(userProgram: userProgram)
                    )
                    .onTapGesture {
                        selectedProgram = program
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Available Programs Section
    
    private var availableProgramsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Programs")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("TextSecondary"))
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                ForEach(availablePrograms) { program in
                    ProgramRowView(
                        program: program,
                        isActive: false,
                        progress: nil
                    )
                    .onTapGesture {
                        if premiumManager.isPremiumUser {
                            selectedProgram = program
                        } else {
                            premiumManager.showPaywall(context: .programAccess)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("No programs available")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color("BackgroundDark"))
            
            Text("Check back soon for new training programs")
                .font(.system(size: 14))
                .foregroundColor(Color("TextSecondary"))
        }
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    
    private func calculateProgress(userProgram: UserProgram) -> Double {
        // Use the programProgress property from the service
        if let progress = programService.programProgress {
            return progress.completionPercentage / 100.0
        }
        return 0.0
    }
}

// MARK: - Program Row Component

struct ProgramRowView: View {
    let program: Program
    let isActive: Bool
    let progress: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title & Duration
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("BackgroundDark"))
                    
                    if let description = program.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color("TextSecondary"))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Duration badge
                Text("\(program.durationWeeks)w")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
            }
            
            // Progress bar (if active)
            if let progress = progress {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color("BackgroundDark").opacity(0.1))
                                .frame(height: 4)
                            
                            // Progress
                            Rectangle()
                                .fill(Color("PrimaryMain"))
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    TrainingProgramsView(isPresentingWorkoutFlow: .constant(false))
        .environmentObject(PremiumManager.shared)
}
// MARK: - Updated Challenges View
struct ChallengesView: View {
    @Binding var isPresentingWorkoutFlow: Bool
    @EnvironmentObject var premiumManager: PremiumManager
    @StateObject private var challengeService = LocalChallengeService.shared
    @State private var selectedChallenge: Challenge?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Challenges")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color("BackgroundDark"))
                        
                        Text("7-day focused challenges designed to build specific skills and push your limits.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color("TextSecondary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                    
                    // Challenges List
                    if challengeService.isLoading {
                        ProgressView()
                            .padding()
                    } else if challengeService.challenges.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 0) {
                            // Active Challenges Section
                            if !enrolledChallenges.isEmpty {
                                activeChallengesSection
                                
                                Spacer()
                                    .frame(height: 40)
                            }
                            
                            // Available Challenges Section
                            availableChallengesSection
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(
                challenge: challenge,
                isPresentingWorkoutFlow: $isPresentingWorkoutFlow
            )
            .environmentObject(challengeService)
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
        .onAppear {
            challengeService.loadChallenges()
            challengeService.loadEnrollmentStatus()
            challengeService.loadUserChallenges()
        }
        .onChange(of: isPresentingWorkoutFlow) { newValue in
            if !newValue {
                dismiss()
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
    }
    
    private var availableChallenges: [Challenge] {
        let enrolledIds = Set(enrolledChallenges.map { $0.1.id })
        return challengeService.challenges.filter { !enrolledIds.contains($0.id) }
    }
    
    // MARK: - Active Challenges Section
    
    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Challenges")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("TextSecondary"))
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                ForEach(enrolledChallenges, id: \.0.id) { userChallenge, challenge in
                    ChallengeRowView(
                        challenge: challenge,
                        isActive: true,
                        progress: calculateProgress(userChallenge: userChallenge)
                    )
                    .onTapGesture {
                        selectedChallenge = challenge
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Available Challenges Section
    
    private var availableChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Challenges")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("TextSecondary"))
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                ForEach(availableChallenges, id: \.id) { (challenge: Challenge) in
                    ChallengeRowView(
                        challenge: challenge,
                        isActive: false,
                        progress: nil
                    )
                    .onTapGesture {
                        if premiumManager.isPremiumUser {
                            selectedChallenge = challenge
                        } else {
                            premiumManager.showPaywall(context: .programAccess)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("No challenges available")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color("BackgroundDark"))
            
            Text("Check back soon for new challenges")
                .font(.system(size: 14))
                .foregroundColor(Color("TextSecondary"))
        }
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    
    private func calculateProgress(userChallenge: UserChallenge) -> Double {
        // Use the challengeProgress property from the service
        if let progress = challengeService.challengeProgress {
            return progress.completionPercentage / 100.0
        }
        return 0.0
    }
}

// MARK: - Challenge Row Component

struct ChallengeRowView: View {
    let challenge: Challenge
    let isActive: Bool
    let progress: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title & Duration
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.system(size: 20, weight: .semibold))
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
            }
            
            // Progress bar (if active)
            if let progress = progress {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color("BackgroundDark").opacity(0.1))
                                .frame(height: 4)
                            
                            // Progress
                            Rectangle()
                                .fill(Color("PrimaryMain"))
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Data Export View
struct DataExportView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    VStack(alignment: .leading, spacing: 16) {                        
                        Text("Manage your workout data and export options")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Premium Data Section
                    PremiumDataSection()
                        .environmentObject(workoutDataManager)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
    }
}

// MARK: - Fixed Size Program Card
struct FixedSizeProgramCard: View {
    let title: String
    let description: String
    let difficulty: String
    let weeks: Int
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(isLocked ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Bottom section with difficulty and weeks
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(difficulty, systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(isLocked ? .secondary : difficultyColor)
                        
                        Spacer()
                        
                        if weeks > 0 {
                            Text("\(weeks)w")
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
                    
                    // Lock indicator or action button
                    if isLocked {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(Color("PrimaryMain"))
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 160) // Fixed height for all cards
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(isLocked ? 0.03 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isLocked ? Color("PrimaryMain").opacity(0.3) : Color.blue.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var difficultyColor: Color {
        switch difficulty.lowercased() {
        case "beginner": return Color("AccentGreen")
        case "intermediate": return .yellow
        case "advanced": return Color("PrimaryMain")
        case "elite": return Color("PrimaryMedium")
        default: return .blue
        }
    }
}

// MARK: - Database Program Card
struct DatabaseProgramCard: View {
    let program: Program
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text(program.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(isLocked ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let description = program.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                // Bottom section with difficulty and weeks
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(program.difficulty.rawValue.capitalized, systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(isLocked ? .secondary : difficultyColor)
                        
                        Spacer()
                        
                        if program.durationWeeks > 0 {
                            Text("\(program.durationWeeks)w")
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
                    
                    // Category badge
                    HStack {
                        Text(program.category.rawValue.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.2))
                            .foregroundColor(categoryColor)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        if program.isFeatured {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    // Lock indicator or action button
                    if isLocked {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(Color("PrimaryMain"))
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 180) // Slightly taller to accommodate category badge
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(isLocked ? 0.03 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isLocked ? Color("PrimaryMain").opacity(0.3) : Color.blue.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var difficultyColor: Color {
        switch program.difficulty {
        case .beginner: return Color("AccentGreen")
        case .intermediate: return .yellow
        case .advanced: return Color("PrimaryMain")
        case .elite: return Color("PrimaryMedium")
        }
    }
    
    private var categoryColor: Color {
        switch program.category {
        case .military: return .red
        case .adventure: return .green
        case .fitness: return .blue
        case .historical: return .purple
        }
    }
}
