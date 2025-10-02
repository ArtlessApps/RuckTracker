# Supabase RLS Policy Fix

## Problem
The program enrollment fails with:
```
Failed to enroll in program: PostgrestError(detail: nil, hint: nil, code: Optional("42501"), message: "new row violates row-level security policy for table \"user_programs\"")
```

## Root Cause
The app is using a **mock user ID** instead of a real authenticated user, causing RLS policies to fail:

1. **Mock User ID**: `ProgramService` uses `mockCurrentUserId: UUID? = UUID()`
2. **No Authentication**: Supabase client isn't authenticated with a real user
3. **RLS Policy Violation**: Policy `auth.uid() = user_id` fails because `auth.uid()` returns `null`

## Solutions

### Option 1: Disable RLS for Development (Quick Fix)
```sql
-- Temporarily disable RLS for user_programs table during development
ALTER TABLE user_programs DISABLE ROW LEVEL SECURITY;
```

### Option 2: Create Development User (Recommended)
```sql
-- Create a development user in Supabase Auth
-- This requires using the Supabase dashboard or API to create a user
-- Then authenticate the client with this user's session
```

### Option 3: Update RLS Policy for Development
```sql
-- Allow inserts with any user_id during development
DROP POLICY "Users can insert their own user programs" ON user_programs;
CREATE POLICY "Allow development inserts" ON user_programs
    FOR INSERT WITH CHECK (true);
```

### Option 4: Implement Proper Authentication
Update the app to use real Supabase authentication instead of mock user IDs.

## Recommended Fix (Option 1 - Quick)
Run this SQL in your Supabase SQL editor:

```sql
-- Disable RLS temporarily for development
ALTER TABLE user_programs DISABLE ROW LEVEL SECURITY;

-- Re-enable when you implement proper authentication
-- ALTER TABLE user_programs ENABLE ROW LEVEL SECURITY;
```

## Testing
After applying the fix:
1. Try enrolling in a program
2. The "Start Program" button should work
3. Check that the enrollment appears in the database

## Long-term Solution
Implement proper Supabase authentication in the app to replace the mock user system.
