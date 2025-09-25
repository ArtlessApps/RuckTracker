import SwiftUI
import Foundation

// MARK: - Training Programs View
struct TrainingProgramsView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var programService = ProgramService()
    @State private var showingProgramDetail = false
    @State private var selectedProgram: Program?
    
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
                        
                        // Grid layout with fixed-size cards
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                            // Military Foundation Program
                            FixedSizeProgramCard(
                                title: "Military Foundation",
                                description: "8-week program for beginners",
                                difficulty: "Beginner",
                                weeks: 8,
                                isLocked: !premiumManager.isPremiumUser
                            ) {
                                if premiumManager.isPremiumUser {
                                    selectedProgram = createMockProgram(
                                        title: "Military Foundation",
                                        description: "8-week foundational program designed for those new to rucking",
                                        difficulty: .beginner,
                                        weeks: 8
                                    )
                                    showingProgramDetail = true
                                } else {
                                    premiumManager.showPaywall(context: .programAccess)
                                }
                            }
                            
                            // Ranger Challenge Program
                            FixedSizeProgramCard(
                                title: "Ranger Challenge",
                                description: "Advanced 12-week training",
                                difficulty: "Advanced",
                                weeks: 12,
                                isLocked: !premiumManager.isPremiumUser
                            ) {
                                if premiumManager.isPremiumUser {
                                    selectedProgram = createMockProgram(
                                        title: "Ranger Challenge",
                                        description: "Advanced 12-week program for experienced ruckers",
                                        difficulty: .advanced,
                                        weeks: 12
                                    )
                                    showingProgramDetail = true
                                } else {
                                    premiumManager.showPaywall(context: .programAccess)
                                }
                            }
                            
                            // Selection Prep Program
                            FixedSizeProgramCard(
                                title: "Selection Prep",
                                description: "16-week intensive program",
                                difficulty: "Elite",
                                weeks: 16,
                                isLocked: !premiumManager.isPremiumUser
                            ) {
                                if premiumManager.isPremiumUser {
                                    selectedProgram = createMockProgram(
                                        title: "Selection Prep",
                                        description: "Elite 16-week program for special operations preparation",
                                        difficulty: .elite,
                                        weeks: 16
                                    )
                                    showingProgramDetail = true
                                } else {
                                    premiumManager.showPaywall(context: .programAccess)
                                }
                            }
                            
                            // Special Forces Program
                            FixedSizeProgramCard(
                                title: "Special Forces",
                                description: "Elite 20-week program",
                                difficulty: "Elite",
                                weeks: 20,
                                isLocked: !premiumManager.isPremiumUser
                            ) {
                                if premiumManager.isPremiumUser {
                                    selectedProgram = createMockProgram(
                                        title: "Special Forces",
                                        description: "Elite 20-week program for the most demanding special operations training",
                                        difficulty: .elite,
                                        weeks: 20
                                    )
                                    showingProgramDetail = true
                                } else {
                                    premiumManager.showPaywall(context: .programAccess)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Additional program information
                    if premiumManager.isPremiumUser {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Program Features")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                FeatureRow(icon: "calendar", title: "Structured Schedule", description: "Weekly plans with rest days and progression")
                                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Monitor your improvement over time")
                                FeatureRow(icon: "person.2.fill", title: "Community Support", description: "Connect with other ruckers on the same journey")
                                FeatureRow(icon: "trophy.fill", title: "Achievement Badges", description: "Earn recognition for completing milestones")
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Training Programs")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingProgramDetail) {
            if let program = selectedProgram {
                ProgramDetailView(program: program)
                    .environmentObject(programService)
            }
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
    }
    
    private func createMockProgram(title: String, description: String, difficulty: Program.Difficulty, weeks: Int) -> Program {
        Program(
            id: UUID(),
            title: title,
            description: description,
            difficulty: difficulty,
            category: .military,
            durationWeeks: weeks,
            isFeatured: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Updated Challenges View
struct ChallengesView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Use the new Stack Challenges Section
                    StackChallengesSection()
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
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("View Program")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
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
                                isLocked ? Color.orange.opacity(0.3) : Color.blue.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var difficultyColor: Color {
        switch difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .yellow
        case "advanced": return .orange
        case "elite": return .red
        default: return .blue
        }
    }
}
