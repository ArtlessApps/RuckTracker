import SwiftUI
import Foundation
import Combine


struct TrainingProgramsView: View {
    @Binding var isPresentingWorkoutFlow: Bool
    @StateObject private var programService = LocalProgramService.shared
    @State private var selectedProgram: Program?
    
    var body: some View {
        ZStack {
            AppColors.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Training Programs")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Structured training plans to build strength, endurance, and consistent rucking habits.")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    
                    // ACTIVE PROGRAMS SECTION
                    if !enrolledPrograms.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Active")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 24)
                            
                            ForEach(enrolledPrograms, id: \.0.id) { userProgram, program in
                                Button(action: {
                                    selectedProgram = program
                                }) {
                                    ActiveProgramCard(
                                        program: program,
                                        progress: calculateProgress(userProgram: userProgram, program: program)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    
                    // AVAILABLE PROGRAMS SECTION
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Available")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 24)
                        
                        ForEach(availablePrograms) { program in
                            Button(action: {
                                selectedProgram = program
                            }) {
                                AvailableProgramCard(program: program)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedProgram) { program in
            ProgramDetailView(
                program: program,
                isPresentingWorkoutFlow: $isPresentingWorkoutFlow,
                onDismiss: {
                    selectedProgram = nil
                }
            )
        }
        .onAppear {
            programService.loadPrograms()
            programService.loadUserPrograms()
            programService.loadEnrollmentStatus()
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
            .sorted { $0.0.startDate > $1.0.startDate }
    }
    
    private var availablePrograms: [Program] {
        let enrolledProgramIds = Set(enrolledPrograms.map { $0.1.id })
        return programService.programs.filter { !enrolledProgramIds.contains($0.id) }
    }
    
    private func calculateProgress(userProgram: UserProgram, program: Program) -> Double {
        return ProgramProgressCalculator.calculateProgress(for: program)
    }
    
}

// MARK: - Active Program Card

struct ActiveProgramCard: View {
    let program: Program
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and duration
            HStack {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.title)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let description = program.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Duration badge
                Text("\(program.durationWeeks)w")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.textSecondary.opacity(0.15))
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
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.textSecondary.opacity(0.15))
                            .frame(height: 6)
                        
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
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var iconName: String {
        let title = program.title.lowercased()
        if title.contains("ruck ready") {
            return "figure.walk"
        } else if title.contains("foundation builder") {
            return "square.stack.3d.up"
        } else if title.contains("active lifestyle") {
            return "heart.fill"
        } else if title.contains("endurance") {
            return "map.fill"
        } else if title.contains("goruck light") {
            return "flame.fill"
        } else if title.contains("goruck heavy") || title.contains("goruck tough") {
            return "bolt.fill"
        } else if title.contains("army acft") {
            return "shield.fill"
        } else if title.contains("strength") && title.contains("conditioning") {
            return "dumbbell.fill"
        } else if title.contains("marathon ruck") {
            return "figure.hiking"
        } else if title.contains("goruck selection") {
            return "flame.fill"
        } else if title.contains("pace pusher") {
            return "hare.fill"
        } else if title.contains("heavy hauler") {
            return "figure.strengthtraining.traditional"
        }
        return "figure.walk"
    }
    
    private var iconColor: Color {
        let title = program.title.lowercased()
        if title.contains("foundation builder") {
            return AppColors.accentTealLight
        } else if title.contains("pace pusher") {
            return AppColors.primary
        } else if title.contains("heavy hauler") {
            return AppColors.accentGreen
        } else if title.contains("endurance") {
            return AppColors.accentTealLight
        } else if title.contains("goruck selection") {
            return AppColors.accentGreenDeep
        } else if title.contains("goruck heavy") || title.contains("goruck tough") {
            return AppColors.accentGreenDeep
        } else if title.contains("army acft") {
            return AppColors.primary
        } else if title.contains("marathon ruck") {
            return AppColors.accentGreen
        }
        return AppColors.primary
    }
}

// MARK: - Available Program Card

struct AvailableProgramCard: View {
    let program: Program
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                if let description = program.description {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(program.durationWeeks)w")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppColors.textSecondary.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private var iconName: String {
        let title = program.title.lowercased()
        if title.contains("ruck ready") {
            return "figure.walk"
        } else if title.contains("foundation builder") {
            return "square.stack.3d.up"
        } else if title.contains("active lifestyle") {
            return "heart.fill"
        } else if title.contains("endurance") {
            return "map.fill"
        } else if title.contains("goruck light") {
            return "flame.fill"
        } else if title.contains("goruck heavy") || title.contains("goruck tough") {
            return "bolt.fill"
        } else if title.contains("army acft") {
            return "shield.fill"
        } else if title.contains("strength") && title.contains("conditioning") {
            return "dumbbell.fill"
        } else if title.contains("marathon ruck") {
            return "figure.hiking"
        } else if title.contains("goruck selection") {
            return "flame.fill"
        } else if title.contains("pace pusher") {
            return "hare.fill"
        } else if title.contains("heavy hauler") {
            return "figure.strengthtraining.traditional"
        }
        return "figure.walk"
    }
    
    private var iconColor: Color {
        let title = program.title.lowercased()
        if title.contains("foundation builder") {
            return AppColors.accentTealLight
        } else if title.contains("pace pusher") {
            return AppColors.primary
        } else if title.contains("heavy hauler") {
            return AppColors.accentGreen
        } else if title.contains("endurance") {
            return AppColors.accentTealLight
        } else if title.contains("goruck selection") {
            return AppColors.accentGreenDeep
        } else if title.contains("goruck heavy") || title.contains("goruck tough") {
            return AppColors.accentGreenDeep
        } else if title.contains("army acft") {
            return AppColors.primary
        } else if title.contains("marathon ruck") {
            return AppColors.accentGreen
        }
        return AppColors.primary
    }
}

// Custom button style for subtle press effect
struct ProgramCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Preview
#Preview {
    TrainingProgramsView(isPresentingWorkoutFlow: .constant(false))
        .environmentObject(PremiumManager.shared)
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
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let description = program.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Text("\(program.durationWeeks)w")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            // Progress bar (if active)
            if let progress = progress {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppColors.textSecondary.opacity(0.15))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(AppColors.primary)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppColors.textSecondary.opacity(0.15), lineWidth: 1)
                )
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
        ZStack {
            AppColors.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Challenges")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Test your limits with focused challenges designed to build specific skills and mental toughness.")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    
                    // ACTIVE CHALLENGES SECTION
                    if !enrolledChallenges.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Active")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 24)
                            
                            ForEach(enrolledChallenges, id: \.0.id) { userChallenge, challenge in
                                Button(action: {
                                    selectedChallenge = challenge
                                }) {
                                    ActiveChallengeCard(
                                        challenge: challenge,
                                        progress: calculateChallengeProgress(userChallenge: userChallenge, challenge: challenge)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    
                    // AVAILABLE CHALLENGES SECTION
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Available")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 24)
                        
                        ForEach(availableChallenges) { challenge in
                            Button(action: {
                                selectedChallenge = challenge
                            }) {
                                AvailableChallengeCard(challenge: challenge)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
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
    
    private func calculateChallengeProgress(userChallenge: UserChallenge, challenge: Challenge) -> Double {
        return ChallengeProgressCalculator.calculateProgress(for: challenge)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(isLocked ? AppColors.textSecondary : AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(difficulty, systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(isLocked ? AppColors.textSecondary : difficultyColor)
                        
                        Spacer()
                        
                        if weeks > 0 {
                            Text("\(weeks)w")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text("Ongoing")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    if isLocked {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.accentWarm)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 160)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface.opacity(isLocked ? 0.5 : 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isLocked ? AppColors.accentWarm.opacity(0.3) : AppColors.textSecondary.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var difficultyColor: Color {
        switch difficulty.lowercased() {
        case "beginner": return AppColors.accentGreenLight
        case "intermediate": return AppColors.primary
        case "advanced": return AppColors.accentWarm
        case "elite": return AppColors.accentGreenDeep
        default: return AppColors.primary
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(program.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(isLocked ? AppColors.textSecondary : AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let description = program.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(program.difficulty.rawValue.capitalized, systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(isLocked ? AppColors.textSecondary : difficultyColor)
                        
                        Spacer()
                        
                        if program.durationWeeks > 0 {
                            Text("\(program.durationWeeks)w")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text("Ongoing")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
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
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    
                    if isLocked {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.accentWarm)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface.opacity(isLocked ? 0.5 : 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isLocked ? AppColors.accentWarm.opacity(0.3) : AppColors.textSecondary.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var difficultyColor: Color {
        switch program.difficulty {
        case .beginner: return AppColors.accentGreenLight
        case .intermediate: return AppColors.primary
        case .advanced: return AppColors.accentWarm
        case .elite: return AppColors.accentGreenDeep
        }
    }
    
    private var categoryColor: Color {
        switch program.category {
        case .military: return AppColors.accentWarm
        case .adventure: return AppColors.accentGreen
        case .fitness: return AppColors.primary
        case .historical: return AppColors.accentTealLight
        }
    }
}
