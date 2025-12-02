import SwiftUI
import CoreLocation

struct PhoneOnboardingView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject var userSettings = UserSettings.shared
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentStep = 0
    @State private var recommendedProgramID: String = ""
    @State private var recommendedProgramTitle: String = ""
    
    var body: some View {
        ZStack {
            Color("BackgroundDark").ignoresSafeArea()
            
            VStack {
                // Progress Bar
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
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
                    
                    // Step 4: The Reveal (The Product)
                    ProgramRecommendationStep(
                        goal: userSettings.ruckingGoal,
                        programTitle: recommendedProgramTitle,
                        nextAction: { nextStep() }
                    )
                    .tag(3)
                    
                    // Step 5: The Buy-in (Permissions)
                    PermissionsStep(
                        healthManager: healthManager, 
                        workoutManager: workoutManager, 
                        onComplete: { hasCompletedOnboarding = true }
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
    }
    
    private func nextStep() {
        currentStep += 1
    }
    
    private func calculateRecommendation() {
        // MAPPING LOGIC: Goals -> Programs.json IDs
        switch userSettings.ruckingGoal {
        case .longevity:
            // "Ruck Ready" - Safe, progressive, focused on form
            recommendedProgramID = "11111111-1111-1111-1111-111111111111"
            recommendedProgramTitle = "Ruck Ready"
            
        case .weightLoss:
            // "Foundation Builder" - Higher volume, consistent burn
            recommendedProgramID = "22222222-2222-2222-2222-222222222222"
            recommendedProgramTitle = "Foundation Builder"
            
        case .hiking:
            // "Endurance Build" - Mileage focus for backcountry
            recommendedProgramID = "44444444-4444-4444-4444-444444444444"
            recommendedProgramTitle = "Endurance Build"
            
        case .goruckBasic:
            // "GORUCK Light Prep" (Now Basic)
            recommendedProgramID = "55555555-5555-5555-5555-555555555555"
            recommendedProgramTitle = "GORUCK Basic Prep"
            
        case .goruckTough:
            // "GORUCK Heavy/Tough Prep"
            recommendedProgramID = "66666666-6666-6666-6666-666666666666"
            recommendedProgramTitle = "Tough Challenge Prep"
            
        case .military:
            // "Army ACFT Prep"
            recommendedProgramID = "77777777-7777-7777-7777-777777777777"
            recommendedProgramTitle = "Military Selection"
        }
        
        // Save to settings
        userSettings.activeProgramID = recommendedProgramID
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
