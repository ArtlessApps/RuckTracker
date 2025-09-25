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
        static let workoutCompletions = "workout_completions"
        static let weightProgressions = "weight_progressions"
        
        // Stack Challenges tables (NEW)
        static let stackChallenges = "stack_challenges"
        static let userChallengeEnrollments = "user_challenge_enrollments"
        static let challengeWorkouts = "challenge_workouts"
        static let userChallengeCompletions = "user_challenge_completions"
        
        // Premium/subscription tables
        static let userSubscriptions = "user_subscriptions"
    }
}

// Example SQL for creating a workouts table in Supabase:
/*
CREATE TABLE workouts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    duration INTERVAL NOT NULL,
    distance DECIMAL(10,2),
    calories INTEGER,
    average_heart_rate INTEGER,
    max_heart_rate INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;

-- Create policy for users to only see their own workouts
CREATE POLICY "Users can view their own workouts" ON workouts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workouts" ON workouts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workouts" ON workouts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own workouts" ON workouts
    FOR DELETE USING (auth.uid() = user_id);
*/
