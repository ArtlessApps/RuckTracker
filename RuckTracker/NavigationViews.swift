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
                        Text("Training Programs")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
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
                        
                        // Always show all programs - locked for non-premium users
                        VStack(spacing: 16) {
                            // Military Foundation Program
                            FunctionalProgramCard(
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
                            FunctionalProgramCard(
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
                            FunctionalProgramCard(
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
                            FunctionalProgramCard(
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
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingProgramDetail) {
            if let program = selectedProgram {
                ProgramDetailView(program: program)
                    .environmentObject(programService)
            }
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

// MARK: - Challenges View
struct ChallengesView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Challenges")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Text("Coming Soon!")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Data Export View
struct DataExportView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Data Export")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Text("Export your workout data")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Data")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
