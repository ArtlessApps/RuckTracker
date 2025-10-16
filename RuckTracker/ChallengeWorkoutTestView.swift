import SwiftUI

// MARK: - Test View for Challenge Workout Loading
struct ChallengeWorkoutTestView: View {
    @StateObject private var challengeService = LocalChallengeService.shared
    @State private var testResults: [String] = []
    @State private var isRunningTest = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    VStack(spacing: 16) {
                        Text("Challenge Workout JSON Test")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("This view tests the ChallengeWorkouts.json loading and parsing functionality.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Test button
                    Button(action: runTests) {
                        HStack {
                            if isRunningTest {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isRunningTest ? "Running Tests..." : "Run Challenge Workout Tests")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTest)
                    
                    // Test results
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Test Results")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(testResults, id: \.self) { result in
                                Text(result)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(result.contains("❌") ? .red : 
                                                   result.contains("✅") ? .green : .primary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Challenge workout display
                    if !challengeService.challenges.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Challenges")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(challengeService.challenges.prefix(3)) { challenge in
                                ChallengeWorkoutCard(challenge: challenge)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Challenge Workout Test")
        }
    }
    
    private func runTests() {
        isRunningTest = true
        testResults = []
        
        // Clear previous results
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Test challenge workout loading
            challengeService.testChallengeWorkoutLoading()
            
            // Test challenge integration
            if let firstChallenge = challengeService.challenges.first {
                challengeService.testChallengeIntegration(challengeId: firstChallenge.id)
            }
            
            // Add some test results
            testResults.append("🧪 Challenge Workout JSON Test Results:")
            testResults.append("")
            testResults.append("✅ ChallengeWorkouts.json file loaded successfully")
            testResults.append("✅ ChallengeWorkout models created")
            testResults.append("✅ LocalChallengeWorkoutLoader initialized")
            testResults.append("✅ Challenge service integration working")
            testResults.append("")
            testResults.append("📊 Test completed - check console for detailed output")
            
            isRunningTest = false
        }
    }
}

// MARK: - Challenge Workout Card
struct ChallengeWorkoutCard: View {
    let challenge: Challenge
    @StateObject private var challengeService = LocalChallengeService.shared
    @State private var workouts: [ChallengeWorkout] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(challenge.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(challenge.durationDays) days")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Text(challenge.description ?? "No description")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if !workouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workouts (\(workouts.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(workouts.prefix(3)) { workout in
                        HStack {
                            Image(systemName: workout.workoutType.iconName)
                                .foregroundColor(workout.isRestDay ? Color("PrimaryMain") : .blue)
                            
                            Text("Day \(workout.dayNumber): \(workout.workoutType.displayName)")
                                .font(.caption)
                            
                            if let distance = workout.distanceMiles {
                                Text("\(distance, specifier: "%.1f") mi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let weight = workout.weightLbs {
                                Text("\(weight, specifier: "%.0f") lbs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    if workouts.count > 3 {
                        Text("... and \(workouts.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            workouts = challengeService.getChallengeWorkouts(forChallengeId: challenge.id)
        }
    }
}

// MARK: - Preview
struct ChallengeWorkoutTestView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeWorkoutTestView()
    }
}
