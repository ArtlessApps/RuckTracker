import SwiftUI

// MARK: - Main Leaderboards View

struct LeaderboardsView: View {
    @StateObject private var leaderboardService = LeaderboardService.shared
    @EnvironmentObject private var premiumManager: PremiumManager
    @State private var selectedTab: LeaderboardType = .weeklyDistance
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Selector
                leaderboardTabSelector
                
                // Content
                TabView(selection: $selectedTab) {
                    WeeklyDistanceLeaderboardView()
                        .tag(LeaderboardType.weeklyDistance)
                    
                    ConsistencyLeaderboardView()
                        .tag(LeaderboardType.consistency)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedTab)
            }
            .navigationTitle("Leaderboards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
            }
            .onAppear {
                Task {
                    await leaderboardService.loadLeaderboards()
                }
            }
            .sheet(isPresented: $showingSettings) {
                LeaderboardSettingsView()
            }
            .refreshable {
                await leaderboardService.loadLeaderboards()
            }
        }
    }
    
    private var leaderboardTabSelector: some View {
        HStack {
            ForEach(LeaderboardType.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.title2)
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? tab.color.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Weekly Distance Leaderboard View

struct WeeklyDistanceLeaderboardView: View {
    @StateObject private var leaderboardService = LeaderboardService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week's Distance Leaders")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Total distance covered this week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            if leaderboardService.isLoading {
                ProgressView("Loading leaderboard...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if leaderboardService.weeklyDistanceLeaderboard.isEmpty {
                emptyStateView(for: .weeklyDistance)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(leaderboardService.weeklyDistanceLeaderboard.enumerated()), id: \.element.id) { index, entry in
                            WeeklyDistanceLeaderboardRow(entry: entry, position: index + 1)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    @ViewBuilder
    private func emptyStateView(for type: LeaderboardType) -> some View {
        VStack(spacing: 16) {
            Image(systemName: type.iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No data yet")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Complete some workouts to see leaderboard data!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Consistency Leaderboard View

struct ConsistencyLeaderboardView: View {
    @StateObject private var leaderboardService = LeaderboardService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Consistency Champions")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Current streak of consecutive weeks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            if leaderboardService.isLoading {
                ProgressView("Loading leaderboard...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if leaderboardService.consistencyLeaderboard.isEmpty {
                emptyStateView(for: .consistency)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(leaderboardService.consistencyLeaderboard.enumerated()), id: \.element.id) { index, entry in
                            ConsistencyLeaderboardRow(entry: entry, position: index + 1)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    @ViewBuilder
    private func emptyStateView(for type: LeaderboardType) -> some View {
        VStack(spacing: 16) {
            Image(systemName: type.iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No streaks yet")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Start building your consistency streak!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Leaderboard Row Components

struct WeeklyDistanceLeaderboardRow: View {
    let entry: WeeklyDistanceEntry
    let position: Int
    
    var positionColor: Color {
        switch position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
    
    var positionIcon: String {
        switch position {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "\(position).circle"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Position indicator
            Image(systemName: positionIcon)
                .font(.title2)
                .foregroundColor(positionColor)
                .frame(width: 30)
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .fontWeight(entry.isCurrentUser ? .bold : .semibold)
                    .foregroundColor(entry.isCurrentUser ? .blue : .primary)
                
                Text("\(entry.totalWorkouts) workouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Distance
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", entry.totalDistance))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                if entry.isCurrentUser {
                    Text("You")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(entry.isCurrentUser ? Color.blue.opacity(0.05) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(entry.isCurrentUser ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

struct ConsistencyLeaderboardRow: View {
    let entry: ConsistencyStreakEntry
    let position: Int
    
    var positionColor: Color {
        switch position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
    
    var positionIcon: String {
        switch position {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "\(position).circle"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Position indicator
            Image(systemName: positionIcon)
                .font(.title2)
                .foregroundColor(positionColor)
                .frame(width: 30)
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .fontWeight(entry.isCurrentUser ? .bold : .semibold)
                    .foregroundColor(entry.isCurrentUser ? .blue : .primary)
                
                Text("Best: \(entry.bestStreak) weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Streak info
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.currentStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if entry.isCurrentUser {
                    Text("You")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(entry.isCurrentUser ? Color.blue.opacity(0.05) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(entry.isCurrentUser ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Leaderboard Settings View

struct LeaderboardSettingsView: View {
    @StateObject private var leaderboardService = LeaderboardService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var showInWeeklyDistance = true
    @State private var showInConsistency = true
    @State private var privacyLevel = UserLeaderboardSettings.PrivacyLevel.public
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Display Settings")) {
                    TextField("Display Name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Leave blank to use 'Anonymous'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Privacy Settings")) {
                    Picker("Privacy Level", selection: $privacyLevel) {
                        ForEach(UserLeaderboardSettings.PrivacyLevel.allCases, id: \.self) { level in
                            Text(level.displayName)
                                .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Levels:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("• Public: Visible to all users")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• Friends: Visible to friends only")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• Private: Only visible to you")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Leaderboard Participation")) {
                    Toggle("Weekly Distance Leaderboard", isOn: $showInWeeklyDistance)
                    Toggle("Consistency Leaderboard", isOn: $showInConsistency)
                }
                
                Section {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
            .navigationTitle("Leaderboard Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }
    
    private func loadCurrentSettings() {
        if let settings = leaderboardService.userSettings {
            displayName = settings.displayName ?? ""
            showInWeeklyDistance = settings.showInWeeklyDistance
            showInConsistency = settings.showInConsistency
            privacyLevel = settings.privacyLevel
        }
    }
    
    private func saveSettings() {
        Task {
            guard let currentSettings = leaderboardService.userSettings else { return }
            
            let updatedSettings = UserLeaderboardSettings(
                id: currentSettings.id,
                userId: currentSettings.userId,
                displayName: displayName.isEmpty ? nil : displayName,
                showInWeeklyDistance: showInWeeklyDistance,
                showInConsistency: showInConsistency,
                privacyLevel: privacyLevel,
                createdAt: currentSettings.createdAt,
                updatedAt: Date()
            )
            
            try await leaderboardService.updateUserSettings(updatedSettings)
            dismiss()
        }
    }
}
