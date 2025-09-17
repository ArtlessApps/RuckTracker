# Supabase Integration Setup

## Overview
Supabase has been successfully added to your RuckTracker project! This guide will help you complete the setup.

## What's Been Added

### 1. Package Dependencies
- Added Supabase Swift package (v2.0.0+) to both iOS and watchOS targets
- Package URL: `https://github.com/supabase/supabase-swift`

### 2. New Files Created
- `SupabaseManager.swift` - Main manager class for Supabase operations
- `SupabaseConfig.swift` - Configuration file for your Supabase credentials

### 3. Updated Files
- `RuckTrackerApp.swift` - Added SupabaseManager as environment object
- `project.pbxproj` - Added package references and dependencies

## Next Steps

### 1. Set Up Your Supabase Project
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note down your project URL and anon key from Settings > API

### 2. Configure Your Credentials
Edit `SupabaseConfig.swift` and replace the placeholder values:

```swift
static let supabaseURL = "https://your-project-id.supabase.co"
static let supabaseAnonKey = "your-anon-key-here"
```

### 3. Set Up Your Database Schema
Run this SQL in your Supabase SQL editor to create the workouts table:

```sql
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

-- Create policies for user data access
CREATE POLICY "Users can view their own workouts" ON workouts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workouts" ON workouts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workouts" ON workouts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own workouts" ON workouts
    FOR DELETE USING (auth.uid() = user_id);
```

### 4. Usage Examples

#### Saving a Workout
```swift
// In your view or manager
@EnvironmentObject var supabaseManager: SupabaseManager

func saveWorkout() async {
    let workout = WorkoutData(
        id: UUID(),
        startDate: Date(),
        endDate: Date(),
        duration: 3600, // 1 hour
        distance: 5.0, // 5 km
        calories: 500,
        averageHeartRate: 120,
        maxHeartRate: 150
    )
    
    do {
        try await supabaseManager.saveWorkout(workout: workout)
        print("Workout saved successfully!")
    } catch {
        print("Error saving workout: \(error)")
    }
}
```

#### Fetching Workouts
```swift
func loadWorkouts() async {
    do {
        let workouts = try await supabaseManager.fetchWorkouts()
        // Update your UI with the fetched workouts
    } catch {
        print("Error fetching workouts: \(error)")
    }
}
```

## Authentication (Optional)
If you want to add user authentication, you can use Supabase Auth:

```swift
// Sign up
try await supabaseManager.client.auth.signUp(
    email: "user@example.com",
    password: "password"
)

// Sign in
try await supabaseManager.client.auth.signIn(
    email: "user@example.com",
    password: "password"
)

// Sign out
try await supabaseManager.client.auth.signOut()
```

## Testing
1. Build and run your project
2. Check that there are no compilation errors
3. Test the Supabase connection by calling one of the example methods

## Troubleshooting
- Make sure your Supabase URL and key are correct
- Check that your database table exists and has the correct schema
- Verify that Row Level Security policies are set up correctly
- Check the Supabase logs for any server-side errors

## Resources
- [Supabase Swift Documentation](https://github.com/supabase/supabase-swift)
- [Supabase Dashboard](https://app.supabase.com)
- [Supabase Documentation](https://supabase.com/docs)
