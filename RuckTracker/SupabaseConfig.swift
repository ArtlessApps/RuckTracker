import Foundation

struct SupabaseConfig {
    // Replace these with your actual Supabase project credentials
    // You can find these in your Supabase project dashboard under Settings > API
    
    static let supabaseURL = "https://zqxxcuvgwadokkgmcuwr.supabase.co" // Your actual URL
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxeHhjdXZnd2Fkb2trZ21jdXdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5OTI4NTIsImV4cCI6MjA3MzU2ODg1Mn0.vU-gcFzN2YyqDWkihIdMGu_LXp0Y--QSB00Vsr9qm_o" // Your actual key
    
    // Optional: Add your service role key for server-side operations (keep this secure!)
    // static let supabaseServiceKey = "YOUR_SERVICE_ROLE_KEY"
    
    // Database table names
    struct Tables {
        // Existing tables
        static let workouts = "workouts"
        static let users = "users"
        static let workoutSessions = "workout_sessions"
        
        // Program tables
        static let programs = "programs"
        static let programWeeks = "program_weeks"
        static let programWorkouts = "program_workouts"
        static let userPrograms = "user_programs"
        static let programProgress = "program_progress"
        static let workoutCompletions = "workout_completions"
        static let weightProgressions = "weight_progressions"
        
        // Stack Challenges tables (NEW)
        static let stackChallenges = "stack_challenges"
        static let userChallengeEnrollments = "user_challenge_enrollments"
        static let challengeWorkouts = "challenge_workouts"
        static let userChallengeCompletions = "user_challenge_completions"
        
        // Premium/subscription tables
        static let userSubscriptions = "user_subscriptions"
        
        // Leaderboard tables
        static let weeklyDistanceLeaderboard = "weekly_distance_leaderboard"
        static let consistencyStreakLeaderboard = "consistency_streak_leaderboard"
        static let userLeaderboardSettings = "user_leaderboard_settings"
    }
}

