import Foundation

struct SupabaseConfig {
    // Replace these with your actual Supabase project credentials
    // You can find these in your Supabase project dashboard under Settings > API
    
    static let supabaseURL = "YOUR_SUPABASE_URL" // e.g., "https://your-project.supabase.co"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY" // Your anon/public key
    
    // Optional: Add your service role key for server-side operations (keep this secure!)
    // static let supabaseServiceKey = "YOUR_SERVICE_ROLE_KEY"
    
    // Database table names
    struct Tables {
        static let workouts = "workouts"
        static let users = "users"
        static let workoutSessions = "workout_sessions"
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
