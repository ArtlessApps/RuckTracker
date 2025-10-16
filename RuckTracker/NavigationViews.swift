import SwiftUI
import Foundation
import Combine

// Import required models and components
// These are defined in other files in the project

// MARK: - Training Programs View
struct TrainingProgramsView: View {
    @Binding var isPresentingWorkoutFlow: Bool
    @EnvironmentObject var premiumManager: PremiumManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var programService = LocalProgramService.shared
    @State private var selectedProgram: Program?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    VStack(alignment: .leading, spacing: 16) {

                        Text("Military-designed structured training plans to build strength, endurance, and mental toughness.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Program cards section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Training Programs")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            if !premiumManager.isPremiumUser {
                                PremiumBadge(size: .small)
                            }
                        }
                        
                        // Dynamic program cards from database
                        if programService.isLoading {
                            ProgressView("Loading programs...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if programService.programs.isEmpty {
                            Text("No programs available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            VStack(spacing: 16) {
                                // ENROLLED PROGRAMS SECTION (NEW)
                                if !enrolledPrograms.isEmpty {
                                    enrolledProgramsSection
                                }
                                
                                // AVAILABLE PROGRAMS SECTION
                                availableProgramsSection
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Training Programs")
            .navigationBarTitleDisplayMode(.large)
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
        // Note: workoutManager is inherited from parent environment
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
        .onChange(of: isPresentingWorkoutFlow) { newValue in
            if !newValue {
                dismiss()
            }
        }
        .onAppear {
            // Load programs and enrollment status when view appears
            programService.loadPrograms()
            programService.loadEnrollmentStatus()
            programService.loadUserPrograms()
        }
        .onReceive(NotificationCenter.default.publisher(for: .programEnrollmentCompleted)) { _ in
            // Refresh enrollment status when enrollment changes
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
            .sorted { $0.0.startDate > $1.0.startDate } // Most recent first
    }
    
    private var availablePrograms: [Program] {
        let enrolledIds = Set(programService.userPrograms.map { $0.programId })
        return programService.programs
            .filter { !enrolledIds.contains($0.id) }
            .sorted { $0.isFeatured && !$1.isFeatured } // Featured first
    }
    
    // MARK: - Enrolled Section
    
    private var enrolledProgramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Programs")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            ForEach(enrolledPrograms, id: \.0.id) { userProgram, program in
                DatabaseProgramCard(
                    program: program,
                    isLocked: false // Enrolled programs are never locked
                ) {
                    selectedProgram = program
                }
                .padding(.horizontal)
            }
            
            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Available Section
    
    private var availableProgramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Programs")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(availablePrograms) { program in
                    DatabaseProgramCard(
                        program: program,
                        isLocked: !premiumManager.isPremiumUser && program.category != .fitness
                    ) {
                        if premiumManager.isPremiumUser || program.category == .fitness {
                            selectedProgram = program
                        } else {
                            premiumManager.showPaywall(context: .programAccess)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Updated Challenges View
struct ChallengesView: View {
    @Binding var isPresentingWorkoutFlow: Bool
    @EnvironmentObject var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Use the new Challenges Section
                    ChallengesSection(isPresentingWorkoutFlow: $isPresentingWorkoutFlow)
                        .environmentObject(premiumManager)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
        .onChange(of: isPresentingWorkoutFlow) { newValue in
            if !newValue {
                dismiss()
            }
        }
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
