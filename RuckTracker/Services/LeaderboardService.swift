import Foundation
import SwiftUI
import Supabase

@MainActor
class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()
    
    @Published var weeklyDistanceLeaderboard: [WeeklyDistanceEntry] = []
    @Published var consistencyLeaderboard: [ConsistencyStreakEntry] = []
    @Published var userSettings: UserLeaderboardSettings?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var supabaseClient: SupabaseClient? {
        SupabaseManager.shared.client
    }
    
    init() {
        // Service is initialized with SupabaseManager
    }
    
    // MARK: - Data Loading
    
    func loadLeaderboards() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let weeklyTask = loadWeeklyDistanceLeaderboard()
            async let consistencyTask = loadConsistencyLeaderboard()
            async let settingsTask = loadUserSettings()
            
            let (_, _, _) = try await (weeklyTask, consistencyTask, settingsTask)
        } catch {
            errorMessage = "Failed to load leaderboards: \(error.localizedDescription)"
            print("❌ Error loading leaderboards: \(error)")
        }
        
        isLoading = false
    }
    
    func loadWeeklyDistanceLeaderboard() async throws {
        guard let client = supabaseClient else {
            // Mock data for testing
            weeklyDistanceLeaderboard = generateMockWeeklyData()
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        do {
            let response: [WeeklyDistanceEntry] = try await client
                .from("weekly_distance_leaderboard")
                .select("*")
                .eq("week_start_date", value: weekStart.ISO8601Format())
                .order("ranking", ascending: true)
                .limit(50)
                .execute()
                .value
            
            weeklyDistanceLeaderboard = response
        } catch {
            print("Failed to load weekly distance leaderboard, using mock data: \(error)")
            weeklyDistanceLeaderboard = generateMockWeeklyData()
        }
    }
    
    func loadConsistencyLeaderboard() async throws {
        guard let client = supabaseClient else {
            // Mock data for testing
            consistencyLeaderboard = generateMockConsistencyData()
            return
        }
        
        do {
            let response: [ConsistencyStreakEntry] = try await client
                .from("consistency_streak_leaderboard")
                .select("*")
                .order("current_streak", ascending: false)
                .limit(50)
                .execute()
                .value
            
            consistencyLeaderboard = response
        } catch {
            print("Failed to load consistency leaderboard, using mock data: \(error)")
            consistencyLeaderboard = generateMockConsistencyData()
        }
    }
    
    func loadUserSettings() async throws {
        guard let client = supabaseClient,
              let userId = try await client.auth.user()?.id else {
            return
        }
        
        do {
            let response: [UserLeaderboardSettings] = try await client
                .from("user_leaderboard_settings")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            userSettings = response.first
            
            // Create default settings if none exist
            if userSettings == nil {
                try await createDefaultUserSettings()
            }
        } catch {
            print("Failed to load user settings: \(error)")
            // Create default settings if loading fails
            try await createDefaultUserSettings()
        }
    }
    
    // MARK: - User Settings Management
    
    func createDefaultUserSettings() async throws {
        guard let client = supabaseClient,
              let userId = try await client.auth.user()?.id else {
            return
        }
        
        let defaultSettings = [
            "user_id": AnyJSON.string(userId.uuidString),
            "show_in_weekly_distance": AnyJSON.bool(true),
            "show_in_consistency": AnyJSON.bool(true),
            "privacy_level": AnyJSON.string("public")
        ]
        
        do {
            try await client
                .from("user_leaderboard_settings")
                .insert(defaultSettings)
                .execute()
            
            await loadUserSettings()
        } catch {
            print("Failed to create default user settings: \(error)")
            // Create mock settings for testing
            userSettings = UserLeaderboardSettings(
                id: UUID(),
                userId: userId,
                displayName: nil,
                showInWeeklyDistance: true,
                showInConsistency: true,
                privacyLevel: .public,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
    
    func updateUserSettings(_ settings: UserLeaderboardSettings) async throws {
        guard let client = supabaseClient else { return }
        
        let updateData = [
            "display_name": settings.displayName.map(AnyJSON.string),
            "show_in_weekly_distance": AnyJSON.bool(settings.showInWeeklyDistance),
            "show_in_consistency": AnyJSON.bool(settings.showInConsistency),
            "privacy_level": AnyJSON.string(settings.privacyLevel.rawValue)
        ].compactMapValues { $0 }
        
        do {
            try await client
                .from("user_leaderboard_settings")
                .update(updateData)
                .eq("user_id", value: settings.userId.uuidString)
                .execute()
            
            userSettings = settings
        } catch {
            print("Failed to update user settings: \(error)")
            // Update local state even if server update fails
            userSettings = settings
        }
    }
    
    // MARK: - Data Updates
    
    func updateUserWeeklyDistance(distance: Double, workoutCount: Int) async throws {
        guard let client = supabaseClient,
              let userId = try await client.auth.user()?.id else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        
        let upsertData = [
            "user_id": AnyJSON.string(userId.uuidString),
            "week_start_date": AnyJSON.string(weekInterval.start.ISO8601Format()),
            "week_end_date": AnyJSON.string(weekInterval.end.ISO8601Format()),
            "total_distance": AnyJSON.number(distance),
            "total_workouts": AnyJSON.number(Double(workoutCount))
        ]
        
        do {
            try await client
                .from("weekly_distance_leaderboard")
                .upsert(upsertData)
                .execute()
        } catch {
            print("Failed to update weekly distance: \(error)")
        }
    }
    
    func updateUserConsistencyStreak(currentStreak: Int, bestStreak: Int, lastWorkoutDate: Date?) async throws {
        guard let client = supabaseClient,
              let userId = try await client.auth.user()?.id else {
            return
        }
        
        var upsertData = [
            "user_id": AnyJSON.string(userId.uuidString),
            "current_streak": AnyJSON.number(Double(currentStreak)),
            "best_streak": AnyJSON.number(Double(bestStreak))
        ]
        
        if let lastWorkoutDate = lastWorkoutDate {
            upsertData["last_workout_date"] = AnyJSON.string(lastWorkoutDate.ISO8601Format())
        }
        
        do {
            try await client
                .from("consistency_streak_leaderboard")
                .upsert(upsertData)
                .execute()
        } catch {
            print("Failed to update consistency streak: \(error)")
        }
    }
    
    // MARK: - Mock Data for Testing
    
    private func generateMockWeeklyData() -> [WeeklyDistanceEntry] {
        let calendar = Calendar.current
        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        
        let mockNames = ["RuckWarrior", "MileEater", "TrailBlazer", "PackMaster", "RuckRookie"]
        
        return (1...5).map { index in
            WeeklyDistanceEntry(
                id: UUID(),
                userId: UUID(),
                weekStartDate: weekInterval.start,
                weekEndDate: weekInterval.end,
                totalDistance: Double.random(in: 15...50),
                totalWorkouts: Int.random(in: 3...7),
                ranking: index,
                createdAt: now,
                updatedAt: now,
                displayName: mockNames[index - 1],
                isCurrentUser: index == 3
            )
        }
    }
    
    private func generateMockConsistencyData() -> [ConsistencyStreakEntry] {
        let now = Date()
        let mockNames = ["Consistent Chad", "Streak Sarah", "Reliable Rob", "Marathon Mike", "Steady Steve"]
        
        return (1...5).map { index in
            ConsistencyStreakEntry(
                id: UUID(),
                userId: UUID(),
                currentStreak: Int.random(in: 5...25),
                bestStreak: Int.random(in: 10...40),
                lastWorkoutDate: now,
                streakStartDate: Calendar.current.date(byAdding: .weekOfYear, value: -Int.random(in: 5...25), to: now),
                ranking: index,
                createdAt: now,
                updatedAt: now,
                displayName: mockNames[index - 1],
                isCurrentUser: index == 2
            )
        }
    }
}
