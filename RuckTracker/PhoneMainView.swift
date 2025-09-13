import SwiftUI

struct ImprovedPhoneMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    @State private var showingSettings = false
    @State private var showingWorkoutHistory = false
    @State private var selectedTimeframe: TimeFrame = .month
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationView {
            mainScrollView
                .navigationTitle("RuckTracker")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    settingsToolbarItem
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingWorkoutHistory) {
            AllWorkoutsView()
        }
    }
    
    // MARK: - Computed Views
    
    private var mainScrollView: some View {
        ScrollView {
            mainContentStack
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
    }
    
    private var mainContentStack: some View {
        LazyVStack(spacing: 24) {
            AppleWatchHeroSection()
            
            if !workoutDataManager.workouts.isEmpty {
                QuickStatsDashboard()
                    .environmentObject(workoutDataManager)
            }
            
            if workoutDataManager.totalWorkouts >= 3 {
                ProgressChartsSection(timeframe: $selectedTimeframe)
                    .environmentObject(workoutDataManager)
            }
            
            RecentActivitySection()
                .environmentObject(workoutDataManager)
            
            if workoutDataManager.totalWorkouts >= 5 {
                TrainingInsightsSection()
                    .environmentObject(workoutDataManager)
                    .environmentObject(workoutManager)
            }
            
            Spacer(minLength: 100)
        }
    }
    
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Sync button
                Button {
                    watchConnectivityManager.requestWorkoutsFromWatch()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(watchConnectivityManager.isWatchReachable ? .blue : .gray)
                }
                .disabled(!watchConnectivityManager.isWatchReachable)
                
                // Settings button
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Hero Section
struct AppleWatchHeroSection: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 20) {
            appleWatchVisualSection
            currentStatusSection
        }
    }
    
    private var appleWatchVisualSection: some View {
        VStack(spacing: 16) {
            watchIcon
            textContent
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(heroBackground)
    }
    
    private var watchIcon: some View {
        Image(systemName: "applewatch.watchface")
            .font(.system(size: 64))
            .foregroundColor(.orange)
            .symbolEffect(.pulse.byLayer, isActive: workoutManager.isActive)
    }
    
    private var textContent: some View {
        VStack(spacing: 8) {
            Text("Track on Apple Watch")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Get accurate GPS, heart rate, and calorie tracking with your ruck weight automatically calculated.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.orange.opacity(0.1))
    }
    
    @ViewBuilder
    private var currentStatusSection: some View {
        if workoutManager.isActive {
            ActiveWorkoutStatusCard()
                .environmentObject(workoutManager)
        } else {
            QuickSetupCard()
                .environmentObject(workoutManager)
        }
    }
}

// MARK: - Active Workout Status
struct ActiveWorkoutStatusCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            statsSection
        }
        .padding()
        .background(cardBackground)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Active on Apple Watch")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("Started recently")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.title2)
                .foregroundColor(.green)
                .symbolEffect(.variableColor.iterative, isActive: true)
        }
    }
    
    private var statsSection: some View {
        HStack {
            StatPill(value: workoutManager.formattedElapsedTime, label: "Time", color: .blue)
            StatPill(value: String(format: "%.2f", workoutManager.distance), label: "Miles", color: .green)
            StatPill(value: "\(Int(workoutManager.calories))", label: "Cal", color: .orange)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.green.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Quick Setup Card
struct QuickSetupCard: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var showingTips = false
    
    var body: some View {
        VStack(spacing: 16) {
            headerRow
            instructionText
        }
        .padding()
        .background(cardBackground)
        .sheet(isPresented: $showingTips) {
            RuckingTipsView()
        }
    }
    
    private var headerRow: some View {
        HStack {
            readyToRuckSection
            Spacer()
            tipsButton
        }
    }
    
    private var readyToRuckSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ready to Ruck")
                .font(.headline)
            
            weightDisplay
        }
    }
    
    private var weightDisplay: some View {
        HStack(spacing: 4) {
            Text("\(String(format: "%.0f", workoutManager.ruckWeight))")
                .font(.title3)
                .fontWeight(.semibold)
            Text(userSettings.preferredWeightUnit.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("loaded")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var tipsButton: some View {
        Button("Tips") {
            showingTips = true
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var instructionText: some View {
        Text("Open the RuckTracker app on your Apple Watch to start tracking your workout with full GPS and health monitoring.")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
    }
}

// MARK: - Quick Stats Dashboard
struct QuickStatsDashboard: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            statsGrid
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("Your Progress")
                .font(.title3)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("Last 30 days")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Workouts",
                value: "\(workoutDataManager.recentWorkoutsThisMonth.count)",
                subtitle: "this month",
                icon: "figure.hiking",
                color: .orange
            )
            
            StatCard(
                title: "Distance",
                value: String(format: "%.1f", workoutDataManager.totalDistance),
                subtitle: userSettings.preferredDistanceUnit.rawValue,
                icon: "location.fill",
                color: .green
            )
            
            StatCard(
                title: "Avg Weight",
                value: String(format: "%.0f", averageRuckWeight),
                subtitle: userSettings.preferredWeightUnit.rawValue,
                icon: "backpack.fill",
                color: .blue
            )
            
            StatCard(
                title: "Calories",
                value: String(format: "%.0f", workoutDataManager.totalCalories),
                subtitle: "burned",
                icon: "flame.fill",
                color: .red
            )
        }
    }
    
    private var averageRuckWeight: Double {
        let weights = workoutDataManager.workouts.map { $0.ruckWeight }
        return weights.isEmpty ? 0 : weights.reduce(0, +) / Double(weights.count)
    }
}

// MARK: - Progress Charts Section
struct ProgressChartsSection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @Binding var timeframe: ImprovedPhoneMainView.TimeFrame
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerWithPicker
            chartsStack
        }
    }
    
    private var headerWithPicker: some View {
        HStack {
            Text("Trends")
                .font(.title3)
                .fontWeight(.semibold)
            
            Spacer()
            
            timeframePicker
        }
    }
    
    private var timeframePicker: some View {
        Picker("Timeframe", selection: $timeframe) {
            ForEach(ImprovedPhoneMainView.TimeFrame.allCases, id: \.self) { frame in
                Text(frame.rawValue).tag(frame)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .frame(width: 180)
    }
    
    private var chartsStack: some View {
        VStack(spacing: 20) {
            distanceChart
            loadChart
        }
    }
    
    private var distanceChart: some View {
        ChartCard(title: "Distance Progress", icon: "chart.line.uptrend.xyaxis") {
            DistanceChart(timeframe: timeframe)
                .frame(height: 120)
        }
    }
    
    private var loadChart: some View {
        ChartCard(title: "Load Distribution", icon: "chart.pie") {
            LoadDistributionChart()
                .frame(height: 120)
        }
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    @State private var showingAllWorkouts = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            contentSection
        }
        .sheet(isPresented: $showingAllWorkouts) {
            AllWorkoutsView()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !workoutDataManager.workouts.isEmpty {
                    viewAllButton
                }
            }
            
            // Sync status
            if let lastSync = watchConnectivityManager.lastSyncDate {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Synced \(lastSync.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if watchConnectivityManager.isWatchReachable {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Tap sync to get workouts from Apple Watch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "applewatch.slash")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("Apple Watch not connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var viewAllButton: some View {
        Button("View All") {
            showingAllWorkouts = true
        }
        .font(.subheadline)
        .foregroundColor(.orange)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        if workoutDataManager.workouts.isEmpty {
            EmptyStateView()
        } else {
            workoutsList
        }
    }
    
    private var workoutsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(workoutDataManager.recentWorkouts.prefix(3)), id: \.objectID) { workout in
                CompactWorkoutRow(workout: workout)
            }
        }
    }
}

// MARK: - Training Insights Section
struct TrainingInsightsSection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training Insights")
                .font(.title3)
                .fontWeight(.semibold)
            
            insightCards
        }
    }
    
    private var insightCards: some View {
        VStack(spacing: 12) {
            InsightCard(
                icon: "target",
                title: "Consistency",
                description: getConsistencyInsight(),
                color: .blue
            )
            
            InsightCard(
                icon: "arrow.up.right",
                title: "Progression",
                description: getProgressionInsight(),
                color: .green
            )
            
            InsightCard(
                icon: "lightbulb",
                title: "Recommendation",
                description: getRecommendation(),
                color: .orange
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func getConsistencyInsight() -> String {
        let recentWorkouts = workoutDataManager.recentWorkoutsThisMonth
        let workoutsPerWeek = Double(recentWorkouts.count) / 4.0
        
        if workoutsPerWeek >= 3 {
            return "Great consistency! You're averaging \(String(format: "%.1f", workoutsPerWeek)) rucks per week."
        } else if workoutsPerWeek >= 2 {
            return "Good progress with \(String(format: "%.1f", workoutsPerWeek)) rucks per week. Try for 3+ weekly."
        } else {
            return "Aim for 2-3 rucks per week to build endurance and strength."
        }
    }
    
    private func getProgressionInsight() -> String {
        let workouts = workoutDataManager.workouts.prefix(10)
        guard !workouts.isEmpty else { return "Start tracking to see progression insights." }
        
        let averageWeight = workouts.map { $0.ruckWeight }.reduce(0, +) / Double(workouts.count)
        
        if averageWeight >= 35 {
            return "Strong load capacity! You're carrying \(String(format: "%.0f", averageWeight))lbs on average."
        } else if averageWeight >= 25 {
            return "Building strength with \(String(format: "%.0f", averageWeight))lbs average. Consider gradual increases."
        } else {
            return "Great foundation! Gradually increase weight by 5lbs every 2-3 weeks."
        }
    }
    
    private func getRecommendation() -> String {
        let bodyWeightKg = userSettings.bodyWeightInKg
        let bodyWeightLbs = bodyWeightKg * 2.20462
        let currentWeight = workoutManager.ruckWeight
        let percentage = (currentWeight / bodyWeightLbs) * 100
        
        if percentage < 15 {
            return "Consider increasing to 15% body weight (\(String(format: "%.0f", bodyWeightLbs * 0.15))lbs) for optimal training."
        } else if percentage > 25 {
            return "High load! Ensure adequate recovery between sessions."
        } else {
            return "Perfect load range! Focus on increasing distance or pace."
        }
    }
}

// MARK: - Supporting Views
struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            iconRow
            valueSection
        }
        .padding()
        .background(cardBackground)
    }
    
    private var iconRow: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Spacer()
        }
    }
    
    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.08))
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            content
        }
        .padding()
        .background(cardBackground)
    }
    
    private var headerRow: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.subheadline)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.08))
    }
}

struct CompactWorkoutRow: View {
    let workout: WorkoutEntity
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        HStack {
            leftSection
            Spacer()
            rightSection
        }
        .padding()
        .background(rowBackground)
    }
    
    private var leftSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            dateAndWeight
            statsRow
        }
    }
    
    private var dateAndWeight: some View {
        HStack(spacing: 8) {
            Text(workout.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("\(Int(workout.ruckWeight))lbs")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            Label(workout.formattedDuration, systemImage: "clock")
            Label(workout.formattedDistance(unit: userSettings.preferredDistanceUnit), systemImage: "location")
            Label("\(Int(workout.calories))", systemImage: "flame")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private var rightSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(workout.formattedPace)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(workout.paceColor))
            
            Text("pace")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.05))
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            iconSection
            textSection
            Spacer()
        }
        .padding()
        .background(cardBackground)
    }
    
    private var iconSection: some View {
        Image(systemName: icon)
            .font(.title3)
            .foregroundColor(color)
            .frame(width: 24)
    }
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.08))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            textContent
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    private var textContent: some View {
        VStack(spacing: 8) {
            Text("Ready to Start Rucking?")
                .font(.headline)
            
            Text("Open RuckTracker on your Apple Watch to record your first weighted walk and start building your fitness journey.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Chart Views (Basic implementations)
struct DistanceChart: View {
    let timeframe: ImprovedPhoneMainView.TimeFrame
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.orange.opacity(0.1))
            .overlay(
                Text("Distance trends chart")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
    }
}

struct LoadDistributionChart: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.blue.opacity(0.1))
            .overlay(
                Text("Load distribution chart")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
    }
}

// MARK: - Tips View
struct RuckingTipsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                gettingStartedSection
                formAndSafetySection
            }
            .navigationTitle("Rucking Tips")
            .toolbar {
                doneButton
            }
        }
    }
    
    private var gettingStartedSection: some View {
        Section("Getting Started") {
            TipRow(icon: "figure.walk", title: "Start Light", description: "Begin with 10-15% of your body weight")
            TipRow(icon: "clock", title: "Build Gradually", description: "Increase weight by 5lbs every 2-3 weeks")
            TipRow(icon: "heart", title: "Listen to Your Body", description: "Rest if you feel pain or excessive fatigue")
        }
    }
    
    private var formAndSafetySection: some View {
        Section("Form & Safety") {
            TipRow(icon: "figure.stand", title: "Posture", description: "Keep shoulders back, core engaged")
            TipRow(icon: "shoe", title: "Footwear", description: "Wear supportive, broken-in boots or shoes")
            TipRow(icon: "drop", title: "Hydration", description: "Bring water, especially for long rucks")
        }
    }
    
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            iconSection
            textSection
        }
        .padding(.vertical, 4)
    }
    
    private var iconSection: some View {
        Image(systemName: icon)
            .font(.title3)
            .foregroundColor(.orange)
            .frame(width: 24)
    }
    
    private var textSection: some View {
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
