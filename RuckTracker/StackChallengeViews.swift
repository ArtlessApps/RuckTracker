//
//  StackChallengeViews.swift
//  RuckTracker
//
//  Views for stack challenges functionality
//

import SwiftUI

// MARK: - Main Stack Challenges Section
struct StackChallengesSection: View {
    @StateObject private var challengeService = StackChallengeService.shared
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var selectedChallenge: StackChallenge?
    @State private var showingAddChallenge = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if premiumManager.isPremiumUser {
                        Button("Create a Custom Challenge") {
                            showingAddChallenge = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                
                Text("1-week focused challenges designed to build specific skills and push your limits.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if challengeService.isLoading {
                ProgressView("Loading challenges...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                challengeSectionsView
            }
        }
        .sheet(item: $selectedChallenge) { challenge in
            StackChallengeDetailView(challenge: challenge)
                .environmentObject(challengeService)
        }
        .sheet(isPresented: $showingAddChallenge) {
            AddChallengeView()
                .environmentObject(challengeService)
        }
        .onAppear {
            Task {
                await challengeService.refreshData()
            }
        }
    }
    
    @ViewBuilder
    private var challengeSectionsView: some View {
        VStack(spacing: 32) {
            // Weekly Challenges Section
            if !challengeService.weeklyChallenges.isEmpty {
                weeklyChallengesSection
            }
            
            
            if challengeService.weeklyChallenges.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "No Challenges Available",
                    description: "Check back later for new stack challenges to test your skills."
                )
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var weeklyChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Focus Challenges")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !premiumManager.isPremiumUser {
                    PremiumBadge(size: .small)
                }
            }
            .padding(.horizontal, 20)
            
            // Grid layout matching program view style
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(challengeService.weeklyChallenges) { challenge in
                    StackChallengeCard(
                        challenge: challenge,
                        isLocked: !premiumManager.isPremiumUser,
                        isEnrolled: challengeService.isUserEnrolled(in: challenge)
                    ) {
                        if premiumManager.isPremiumUser {
                            selectedChallenge = challenge
                        } else {
                            premiumManager.showPaywall(context: .featureUpsell)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
}

// MARK: - Stack Challenge Card (Matches Program Card Style)
struct StackChallengeCard: View {
    let challenge: StackChallenge
    let isLocked: Bool
    let isEnrolled: Bool
    let action: () -> Void
    
    var focusColor: Color {
        switch challenge.focusArea.color {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and focus badge
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(challenge.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .foregroundColor(isLocked ? .secondary : .primary)
                        
                        Spacer()
                        
                    }
                    
                    Text(challenge.description ?? "Challenge description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Bottom section with focus and duration
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(challenge.focusArea.displayName, systemImage: challenge.focusArea.iconName)
                            .font(.caption2)
                            .foregroundColor(isLocked ? .secondary : focusColor)
                        
                        Spacer()
                        
                        Text("\(challenge.durationDays)d")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    // Status indicator
                    if isEnrolled {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Enrolled")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                    } else if isLocked {
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
                        }
                    }
                }
            }
            .frame(height: 160) // Fixed height matching program cards
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(isLocked ? 0.03 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isLocked ? Color.orange.opacity(0.3) : 
                                isEnrolled ? Color.green.opacity(0.3) : focusColor.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stack Challenge Detail View
struct StackChallengeDetailView: View {
    let challenge: StackChallenge
    @EnvironmentObject var challengeService: StackChallengeService
    @Environment(\.dismiss) private var dismiss
    @State private var challengeWorkouts: [ChallengeWorkout] = []
    @State private var showingEnrollment = false
    
    var isEnrolled: Bool {
        challengeService.isUserEnrolled(in: challenge)
    }
    
    var userEnrollment: UserChallengeEnrollment? {
        challengeService.getUserEnrollment(for: challenge)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    challengeHeaderSection
                    challengeOverviewSection
                    weekPlanSection
                    enrollmentSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle(challenge.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingEnrollment) {
            ChallengeEnrollmentViewWrapper(challenge: challenge)
                .environmentObject(challengeService)
        }
        .onAppear {
            Task {
                challengeWorkouts = await challengeService.loadChallengeWorkouts(for: challenge.id)
            }
        }
    }
    
    @ViewBuilder
    private var challengeHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: challenge.focusArea.iconName)
                            .font(.title2)
                            .foregroundColor(focusColor)
                        
                        Text(challenge.focusArea.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(focusColor)
                        
                    }
                    
                    if let description = challenge.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(challenge.durationDays)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(focusColor)
                    
                    Text("days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            challengeStatsRow
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(focusColor.opacity(0.05))
        )
    }
    
    @ViewBuilder
    private var challengeStatsRow: some View {
        HStack(spacing: 16) {
            if let weightPercentage = challenge.weightPercentage {
                StatItem(
                    icon: "scalemass.fill",
                    title: "Target Weight",
                    value: "\(Int(weightPercentage))% BW",
                    color: focusColor
                )
            }
            
            if let paceTarget = challenge.paceTarget {
                StatItem(
                    icon: "speedometer",
                    title: "Target Pace",
                    value: "\(Int(paceTarget)) min/mi",
                    color: focusColor
                )
            }
            
            if challenge.distanceFocus {
                StatItem(
                    icon: "location.fill",
                    title: "Focus",
                    value: "Distance",
                    color: focusColor
                )
            }
            
            if challenge.recoveryFocus {
                StatItem(
                    icon: "heart.fill",
                    title: "Focus",
                    value: "Recovery",
                    color: focusColor
                )
            }
        }
    }
    
    @ViewBuilder
    private var challengeOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Overview")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                OverviewRow(
                    icon: "target",
                    title: "Duration",
                    description: "\(challenge.durationDays) consecutive days"
                )
                
                OverviewRow(
                    icon: challenge.focusArea.iconName,
                    title: "Focus Area",
                    description: challenge.focusArea.displayName
                )
                
                
            }
        }
    }
    
    @ViewBuilder
    private var weekPlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Plan")
                .font(.title3)
                .fontWeight(.semibold)
            
            if challengeWorkouts.isEmpty {
                Text("Workout plan will be available after enrollment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(challengeWorkouts) { workout in
                        ChallengeWorkoutRow(workout: workout)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var enrollmentSection: some View {
        VStack(spacing: 16) {
            if isEnrolled {
                enrolledSection
            } else {
                availableEnrollmentSection
            }
        }
    }
    
    @ViewBuilder
    private var enrolledSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Challenge")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let enrollment = userEnrollment {
                        Text("Current weight: \(Int(enrollment.currentWeightLbs)) lbs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Button("View Your Progress") {
                navigateToChallenge = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green)
            )
        }
    }
    
    @ViewBuilder
    private var availableEnrollmentSection: some View {
        VStack(spacing: 12) {
            Text("Ready to start this challenge?")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Select your starting weight and begin the \(challenge.durationDays)-day challenge.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start Challenge") {
                showingEnrollment = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(focusColor)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private var focusColor: Color {
        switch challenge.focusArea.color {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        default: return .blue
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct OverviewRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ChallengeWorkoutRow: View {
    let workout: ChallengeWorkout
    
    var body: some View {
        HStack(spacing: 12) {
            // Day number
            Text("\(workout.dayNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(workout.isRestDay ? Color.orange : Color.blue)
                )
            
            // Workout details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: workout.workoutType.iconName)
                        .font(.caption)
                        .foregroundColor(workout.isRestDay ? .orange : .blue)
                    
                    Text(workout.workoutType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let distance = workout.distanceMiles {
                        Text("• \(String(format: "%.1f", distance)) mi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let weight = workout.weightLbs {
                        Text("• \(Int(weight)) lbs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let instructions = workout.instructions {
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Challenge Enrollment View Wrapper
struct ChallengeEnrollmentViewWrapper: View {
    let challenge: StackChallenge
    @StateObject private var challengeManager = ChallengeManager()
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("Preparing enrollment...")
                        .padding()
                }
            } else {
                ChallengeEnrollmentView(
                    challenge: challenge,
                    challengeManager: challengeManager
                )
            }
        }
        .task {
            await challengeManager.loadChallenge(challenge)
            isLoading = false
        }
    }
}

// MARK: - Add Challenge View (Admin)
struct AddChallengeView: View {
    @EnvironmentObject var challengeService: StackChallengeService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var focusArea: StackChallenge.FocusArea = .power
    @State private var durationDays = 7
    @State private var weightPercentage: Double?
    @State private var paceTarget: Double?
    @State private var distanceFocus = false
    @State private var recoveryFocus = false
    @State private var isAdding = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Challenge Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Challenge Settings") {
                    Picker("Focus Area", selection: $focusArea) {
                        ForEach(StackChallenge.FocusArea.allCases, id: \.self) { focus in
                            Text(focus.displayName).tag(focus)
                        }
                    }
                    
                    Stepper("Duration: \(durationDays) days", value: $durationDays, in: 1...30)
                }
                
                Section("Challenge Parameters") {
                    Toggle("Distance Focus", isOn: $distanceFocus)
                    Toggle("Recovery Focus", isOn: $recoveryFocus)
                    
                    HStack {
                        Text("Weight Percentage")
                        Spacer()
                        if let weight = weightPercentage {
                            Text("\(Int(weight))%")
                                .foregroundColor(.secondary)
                        }
                        Button(weightPercentage == nil ? "Add" : "Remove") {
                            if weightPercentage == nil {
                                weightPercentage = 25.0
                            } else {
                                weightPercentage = nil
                            }
                        }
                        .font(.caption)
                    }
                    
                    if let _ = weightPercentage {
                        Slider(value: Binding(
                            get: { weightPercentage ?? 25.0 },
                            set: { weightPercentage = $0 }
                        ), in: 10...50, step: 2.5)
                    }
                    
                    HStack {
                        Text("Pace Target (min/mile)")
                        Spacer()
                        if let pace = paceTarget {
                            Text("\(Int(pace)) min")
                                .foregroundColor(.secondary)
                        }
                        Button(paceTarget == nil ? "Add" : "Remove") {
                            if paceTarget == nil {
                                paceTarget = 20.0
                            } else {
                                paceTarget = nil
                            }
                        }
                        .font(.caption)
                    }
                    
                    if let _ = paceTarget {
                        Slider(value: Binding(
                            get: { paceTarget ?? 20.0 },
                            set: { paceTarget = $0 }
                        ), in: 12...30, step: 0.5)
                    }
                }
                
            }
            .navigationTitle("Add Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { addChallenge() }
                        .disabled(title.isEmpty || isAdding)
                }
            }
        }
    }
    
    private func addChallenge() {
        isAdding = true
        
        let newChallenge = StackChallenge(
            id: UUID(),
            title: title,
            description: description.isEmpty ? nil : description,
            focusArea: focusArea,
            durationDays: durationDays,
            weightPercentage: weightPercentage,
            paceTarget: paceTarget,
            distanceFocus: distanceFocus,
            recoveryFocus: recoveryFocus,
            season: nil,
            isActive: true,
            sortOrder: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        Task {
            do {
                try await challengeService.addChallenge(newChallenge)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error adding challenge: \(error)")
                // TODO: Show error alert
            }
            
            await MainActor.run {
                isAdding = false
            }
        }
    }
}

// MARK: - Step 6: Update your existing StackChallengeViews.swift file
// Replace or add these components to integrate with the universal challenge system

// MARK: - Updated StackChallengeSection to use UniversalChallengeView
struct StackChallengeSection: View {
    @EnvironmentObject var challengeService: StackChallengeService
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var selectedChallenge: StackChallenge?
    @State private var showingChallengeDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Stack Challenges")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Spacer()
                
                if !premiumManager.isPremiumUser {
                    PremiumBadge(size: .small)
                }
            }
            
            Text("1 Week Fitness Challenges")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Challenge Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(challengeService.weeklyChallenges) { challenge in
                    UpdatedStackChallengeCardView(
                        challenge: challenge,
                        isLocked: !premiumManager.isPremiumUser,
                        isEnrolled: challengeService.isUserEnrolled(in: challenge),
                        onTap: {
                            selectedChallenge = challenge
                            showingChallengeDetail = true
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
        .sheet(isPresented: $showingChallengeDetail) {
            if let challenge = selectedChallenge {
                UniversalChallengeView(challenge: challenge)
                    .environmentObject(challengeService)
                    .environmentObject(premiumManager)
            }
        }
        .task {
            await challengeService.loadChallenges()
        }
    }
}

// MARK: - Updated StackChallengeCardView with proper action handling
struct UpdatedStackChallengeCardView: View {
    let challenge: StackChallenge
    let isLocked: Bool
    let isEnrolled: Bool
    let onTap: () -> Void
    @EnvironmentObject var premiumManager: PremiumManager
    
    private var focusColor: Color {
        Color(challenge.focusArea.color)
    }
    
    var body: some View {
        Button(action: {
            if isLocked {
                // Show premium paywall for locked challenges
                premiumManager.showPaywall(context: .featureUpsell)
            } else {
                // Navigate to universal challenge view
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: challenge.focusArea.iconName)
                        .font(.title3)
                        .foregroundColor(isLocked ? .secondary : focusColor)
                    
                    Spacer()
                    
                    Text("\(challenge.durationDays)d")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Text(challenge.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isLocked ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                
                if let description = challenge.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Status indicator
                HStack {
                    if isEnrolled {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Enrolled")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
            }
            .frame(height: 160) // Fixed height matching program cards
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(isLocked ? 0.03 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isLocked ? Color.orange.opacity(0.3) : 
                                isEnrolled ? Color.green.opacity(0.3) : focusColor.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Challenge Detail Integration
// Update your existing StackChallengeDetailView to navigate to UniversalChallengeView after enrollment

struct UpdatedStackChallengeDetailView: View {
    let challenge: StackChallenge
    @EnvironmentObject var challengeService: StackChallengeService
    @EnvironmentObject var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEnrollment = false
    @State private var navigateToChallenge = false
    
    private var isEnrolled: Bool {
        challengeService.isUserEnrolled(in: challenge)
    }
    
    private var userEnrollment: UserChallengeEnrollment? {
        challengeService.getUserEnrollment(for: challenge)
    }
    
    private var focusColor: Color {
        Color(challenge.focusArea.color)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Challenge Header
                challengeHeaderSection
                
                // Challenge Stats
                challengeStatsSection
                
                // Challenge Overview
                challengeOverviewSection
                
                // Enrollment or Progress Section
                if isEnrolled {
                    enrolledSection
                } else {
                    enrollmentSection
                }
            }
            .padding()
        }
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingEnrollment) {
            ChallengeEnrollmentViewWrapper(challenge: challenge)
        }
        .fullScreenCover(isPresented: $navigateToChallenge) {
            UniversalChallengeView(challenge: challenge)
                .environmentObject(challengeService)
                .environmentObject(premiumManager)
        }
    }
    
    private var challengeHeaderSection: some View {
        VStack(spacing: 16) {
            Image(systemName: challenge.focusArea.iconName)
                .font(.system(size: 60))
                .foregroundColor(focusColor)
            
            Text(challenge.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if let description = challenge.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var challengeStatsSection: some View {
        HStack(spacing: 20) {
            StatItem(
                icon: "calendar",
                title: "Duration",
                value: "\(challenge.durationDays) days",
                color: focusColor
            )
            
            StatItem(
                icon: challenge.focusArea.iconName,
                title: "Focus",
                value: challenge.focusArea.displayName,
                color: focusColor
            )
            
            if let weightPercentage = challenge.weightPercentage {
                StatItem(
                    icon: "scalemass.fill",
                    title: "Weight",
                    value: "\(Int(weightPercentage))% BW",
                    color: focusColor
                )
            }
            
            if let paceTarget = challenge.paceTarget {
                StatItem(
                    icon: "speedometer",
                    title: "Target Pace",
                    value: "\(Int(paceTarget)) min/mi",
                    color: focusColor
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var challengeOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Overview")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                OverviewRow(
                    icon: "target",
                    title: "Duration",
                    description: "\(challenge.durationDays) consecutive days of focused training"
                )
                
                OverviewRow(
                    icon: challenge.focusArea.iconName,
                    title: "Focus Area",
                    description: "\(challenge.focusArea.displayName) development and improvement"
                )
                
                OverviewRow(
                    icon: "calendar.badge.checkmark",
                    title: "Structure",
                    description: "Daily workouts with built-in recovery periods"
                )
                
                OverviewRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progression",
                    description: "Systematically designed to build your capabilities"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var enrolledSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Enrolled in Challenge")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if let enrollment = userEnrollment {
                VStack(spacing: 12) {
                    HStack {
                        Text("Current Weight:")
                        Spacer()
                        Text("\(Int(enrollment.currentWeightLbs)) lbs")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Progress:")
                        Spacer()
                        Text("\(Int(enrollment.completionPercentage))%")
                            .fontWeight(.medium)
                            .foregroundColor(focusColor)
                    }
                    
                    ProgressView(value: enrollment.completionPercentage / 100.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: focusColor))
                        .scaleEffect(y: 2)
                }
                .font(.subheadline)
            }
            
            Button(action: {
                navigateToChallenge = true
            }) {
                Text("Continue Challenge")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(focusColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var enrollmentSection: some View {
        VStack(spacing: 16) {
            Text("Ready to Start?")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Enroll in this challenge to get personalized workouts and track your progress through \(challenge.durationDays) days of focused training.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                if premiumManager.isPremiumUser {
                    showingEnrollment = true
                } else {
                    premiumManager.showPaywall(context: .featureUpsell)
                }
            }) {
                HStack {
                    if !premiumManager.isPremiumUser {
                        Image(systemName: "lock.fill")
                    }
                    Text(premiumManager.isPremiumUser ? "Enroll in Challenge" : "Upgrade to Enroll")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(premiumManager.isPremiumUser ? focusColor : .orange)
                )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Integration Instructions for PhoneMainView.swift
/*
To integrate this with your PhoneMainView.swift, replace your existing challengesCard with:

private var challengesCard: some View {
    Button(action: {
        if premiumManager.isPremiumUser {
            showingChallenges = true
        } else {
            premiumManager.showPaywall(context: .featureUpsell)
        }
    }) {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stack Challenges")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    if !premiumManager.isPremiumUser {
                        PremiumBadge(size: .small)
                    }
                }
                Text("1 Week Fitness Challenges")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $showingChallenges) {
        UniversalChallengeListView()
            .environmentObject(premiumManager)
    }
}

And add this new view for the challenge list:
*/

struct UniversalChallengeListView: View {
    @StateObject private var challengeService = StackChallengeService.shared
    @EnvironmentObject var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChallenge: StackChallenge?
    @State private var showingChallengeDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Weekly Challenges Section
                    if !challengeService.weeklyChallenges.isEmpty {
                        challengeSection(
                            title: "Weekly Focus Challenges",
                            subtitle: "7-day specialized training programs",
                            challenges: challengeService.weeklyChallenges
                        )
                    }
                    
                    
                    if challengeService.isLoading {
                        ProgressView("Loading challenges...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Stack Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingChallengeDetail) {
            if let challenge = selectedChallenge {
                UniversalChallengeView(challenge: challenge)
                    .environmentObject(challengeService)
                    .environmentObject(premiumManager)
            }
        }
        .task {
            await challengeService.loadChallenges()
        }
    }
    
    private func challengeSection(title: String, subtitle: String, challenges: [StackChallenge]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(challenges) { challenge in
                    UpdatedStackChallengeCardView(
                        challenge: challenge,
                        isLocked: !premiumManager.isPremiumUser,
                        isEnrolled: challengeService.isUserEnrolled(in: challenge),
                        onTap: {
                            selectedChallenge = challenge
                            showingChallengeDetail = true
                        }
                    )
                    .environmentObject(premiumManager)
                }
            }
        }
    }
}

