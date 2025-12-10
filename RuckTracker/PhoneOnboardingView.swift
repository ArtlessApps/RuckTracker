import SwiftUI
import CoreLocation

struct PhoneOnboardingView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var programService = LocalProgramService.shared
    @ObservedObject var userSettings = UserSettings.shared
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentStep = 0
    @State private var recommendedProgramID: String = ""
    @State private var recommendedProgramTitle: String = ""
    @State private var baselinePaceInput: String = "16"
    @State private var baselineDistanceInput: String = "4"
    @State private var eventDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var hillAccess: Bool = true
    @State private var stairsAccess: Bool = false
    @State private var injuryNotes: String = ""
    
    var body: some View {
        ZStack {
            Color("BackgroundDark").ignoresSafeArea()
            
            VStack {
                // Progress Bar
                HStack(spacing: 4) {
                    ForEach(0..<8) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color("PrimaryMain") : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                TabView(selection: $currentStep) {
                    // Step 1: The Welcome (Identity)
                    WelcomeCoachStep(nextAction: { nextStep() })
                        .tag(0)
                    
                    // Step 2: The Goal (Psychology)
                    GoalSelectionStep(selectedGoal: $userSettings.ruckingGoal, nextAction: { nextStep() })
                        .tag(1)
                    
                    // Step 3: Experience (Calibration)
                    ExperienceSelectionStep(selectedExperience: $userSettings.experienceLevel, nextAction: { 
                        calculateRecommendation()
                        nextStep() 
                    })
                    .tag(2)
                    
                    // Step 4: Baseline Metrics
                    BaselineMetricsStep(
                        baselinePace: $baselinePaceInput,
                        baselineDistance: $baselineDistanceInput,
                        nextAction: { applyBaselines(); nextStep() }
                    )
                    .tag(3)
                    
                    // Step 5: Terrain & Event (Context)
                    TerrainEventStep(
                        eventDate: $eventDate,
                        hasHills: $hillAccess,
                        hasStairs: $stairsAccess,
                        injuryNotes: $injuryNotes,
                        nextAction: { applyTerrainAndInjuries(); nextStep() },
                        backAction: previousStep
                    )
                    .tag(4)
                    
                    // Step 6: Preferred Training Days (Schedule)
                    TrainingDaysSelectionStep(selectedDays: $userSettings.preferredTrainingDays, nextAction: { nextStep() })
                        .tag(5)
                    
                    // Step 7: The Reveal (The Product)
                    ProgramRecommendationStep(
                        goal: userSettings.ruckingGoal,
                        programTitle: recommendedProgramTitle,
                        nextAction: { nextStep() }
                    )
                    .tag(6)
                    
                    // Step 8: The Buy-in (Permissions)
                    PermissionsStep(
                        healthManager: healthManager, 
                        workoutManager: workoutManager, 
                        onComplete: { hasCompletedOnboarding = true }
                    )
                    .tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
        .onAppear {
            baselinePaceInput = String(format: "%.0f", userSettings.baselinePaceMinutesPerMile)
            baselineDistanceInput = String(format: "%.0f", userSettings.baselineLongestDistanceMiles)
            eventDate = userSettings.targetEventDate ?? eventDate
            hillAccess = userSettings.hasHillAccess
            stairsAccess = userSettings.hasStairsAccess
            injuryNotes = userSettings.injuryFlags.joined(separator: ", ")
        }
    }
    
    private func nextStep() {
        currentStep += 1
    }
    
    private func previousStep() {
        currentStep = max(0, currentStep - 1)
    }
    
    private func calculateRecommendation() {
        let generated = MarchPlanGenerator.generatePlan(for: userSettings)
        programService.upsertMarchProgram(generated)
        
        recommendedProgramID = generated.program.id.uuidString
        recommendedProgramTitle = generated.program.title
        userSettings.activeProgramID = recommendedProgramID
    }
    
    private func applyBaselines() {
        if let pace = Double(baselinePaceInput) {
            userSettings.baselinePaceMinutesPerMile = pace
        }
        if let distance = Double(baselineDistanceInput) {
            userSettings.baselineLongestDistanceMiles = distance
        }
    }
    
    private func applyTerrainAndInjuries() {
        userSettings.targetEventDate = eventDate
        userSettings.hasHillAccess = hillAccess
        userSettings.hasStairsAccess = stairsAccess
        userSettings.injuryFlags = injuryNotes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

// MARK: - Subviews

struct WelcomeCoachStep: View {
    var nextAction: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("MARCH")
                .font(.system(size: 60, weight: .black))
                .foregroundColor(Color("PrimaryMain"))
            Text("POCKET COACH")
                .font(.headline)
                .tracking(4)
                .foregroundColor(.white)
            
            Text("Training for longevity, hunting, or a GORUCK event?\n\nWe build the plan. You do the work.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding()
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Build My Plan")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryMain"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }
}

struct GoalSelectionStep: View {
    @Binding var selectedGoal: RuckingGoal
    var nextAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What are we training for?")
                .font(.title).bold().foregroundColor(.white)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(RuckingGoal.allCases, id: \.self) { goal in
                        Button(action: {
                            selectedGoal = goal
                            nextAction()
                        }) {
                            HStack {
                                Image(systemName: goal.icon)
                                    .frame(width: 30)
                                Text(goal.rawValue)
                                    .font(.headline)
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(selectedGoal == goal ? Color("PrimaryMain") : .white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedGoal == goal ? Color("PrimaryMain") : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ExperienceSelectionStep: View {
    @Binding var selectedExperience: ExperienceLevel
    var nextAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What is your baseline?")
                .font(.title).bold().foregroundColor(.white)
            
            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                Button(action: {
                    selectedExperience = level
                    nextAction()
                }) {
                    HStack {
                        Text(level.rawValue)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct TrainingDaysSelectionStep: View {
    @Binding var selectedDays: [Int]
    var nextAction: () -> Void
    
    private let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon-Sun display order
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("When do you want to train?")
                .font(.title).bold().foregroundColor(.white)
            
            Text("Pick the days you can consistently ruck. We'll schedule workouts around your life.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(orderedWeekdays, id: \.self) { day in
                    Button(action: { toggle(day) }) {
                        VStack(spacing: 8) {
                            Text(shortLabel(for: day))
                                .font(.headline)
                            Text(longLabel(for: day))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isSelected(day) ? Color("PrimaryMain") : Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected(day) ? Color("PrimaryMain") : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Lock Schedule")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedDays.isEmpty ? Color.gray.opacity(0.3) : Color("PrimaryMain"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(selectedDays.isEmpty)
        }
        .padding()
    }
    
    private func toggle(_ day: Int) {
        if let index = selectedDays.firstIndex(of: day) {
            selectedDays.remove(at: index)
        } else {
            selectedDays.append(day)
        }
    }
    
    private func isSelected(_ day: Int) -> Bool {
        selectedDays.contains(day)
    }
    
    private func shortLabel(for day: Int) -> String {
        let index = (day - 1 + 7) % 7
        return calendar.shortWeekdaySymbols[index]
    }
    
    private func longLabel(for day: Int) -> String {
        let index = (day - 1 + 7) % 7
        return calendar.weekdaySymbols[index]
    }
}

struct BaselineMetricsStep: View {
    @Binding var baselinePace: String
    @Binding var baselineDistance: String
    var nextAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Calibrate your plan")
                .font(.title).bold().foregroundColor(.white)
            Text("Tell us your current best effort so we scale load and pace safely.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Best sustainable pace (min/mi)")
                    .foregroundColor(.white.opacity(0.8))
                TextField("16", text: $baselinePace)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Longest recent ruck (miles)")
                    .foregroundColor(.white.opacity(0.8))
                TextField("4", text: $baselineDistance)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Continue")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryMain"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct TerrainEventStep: View {
    @Binding var eventDate: Date
    @Binding var hasHills: Bool
    @Binding var hasStairs: Bool
    @Binding var injuryNotes: String
    var nextAction: () -> Void
    var backAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Context matters")
                .font(.title).bold().foregroundColor(.white)
            Text("We’ll bias sessions toward your terrain and timeline.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            DatePicker("Target event date", selection: $eventDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundColor(.white)
            
            Toggle("I have hills nearby", isOn: $hasHills)
                .toggleStyle(SwitchToggleStyle(tint: Color("PrimaryMain")))
                .foregroundColor(.white)
            
            Toggle("I can use stairs for elevation", isOn: $hasStairs)
                .toggleStyle(SwitchToggleStyle(tint: Color("PrimaryMain")))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Injury considerations (comma separated)")
                    .foregroundColor(.white.opacity(0.8))
                TextField("e.g., knees, plantar", text: $injuryNotes)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            HStack {
                Button(action: backAction) {
                    Text("Back")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: nextAction) {
                    Text("Continue")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("PrimaryMain"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

struct ProgramRecommendationStep: View {
    let goal: RuckingGoal
    let programTitle: String
    var nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(Color("PrimaryMain"))
            
            Text("PLAN GENERATED")
                .font(.caption).bold().tracking(2)
                .foregroundColor(.gray)
            
            Text(programTitle.uppercased())
                .font(.title).bold().foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                RecommendationRow(icon: "calendar", text: "4-8 Week Progression")
                RecommendationRow(icon: "scalemass.fill", text: "Weight Ramp-up")
                if goal == .hiking {
                    RecommendationRow(icon: "mountain.2.fill", text: "Elevation Focus")
                } else if goal == .military {
                    RecommendationRow(icon: "stopwatch.fill", text: "Pace Standards")
                } else {
                    RecommendationRow(icon: "heart.fill", text: "Zone 2 Cardio")
                }
            }
            .padding(30)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Start Training")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryMain"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }
}

struct RecommendationRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(Color("PrimaryMain"))
            Text(text)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// PermissionsStep can remain similar to previous iteration or just generic permissions
struct PermissionsStep: View {
    @ObservedObject var healthManager: HealthManager
    @ObservedObject var workoutManager: WorkoutManager
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Final Setup")
                .font(.title).bold().foregroundColor(.white)
            Text("To be your coach, we need to see your data.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            // Simplified for brevity
            Button(action: { healthManager.requestAuthorization() }) {
                Text("Connect HealthKit")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(healthManager.isAuthorized ? Color.green : Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Button(action: { workoutManager.requestLocationPermission() }) {
                Text("Enable GPS")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Spacer()
            
            Button(action: onComplete) {
                Text("Let's Ruck")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryMain"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
}
