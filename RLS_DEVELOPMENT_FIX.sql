-- RLS Development Fix for RuckTracker
-- This script temporarily disables RLS for development purposes

-- =============================================
-- QUICK FIX: Disable RLS for Development
-- =============================================

-- Disable RLS on user_programs table to allow development
ALTER TABLE user_programs DISABLE ROW LEVEL SECURITY;

-- Also disable RLS on related tables that might cause issues
ALTER TABLE program_progress DISABLE ROW LEVEL SECURITY;
ALTER TABLE workout_completions DISABLE ROW LEVEL SECURITY;
ALTER TABLE weight_progressions DISABLE ROW LEVEL SECURITY;

-- =============================================
-- ALTERNATIVE: Update RLS Policies for Development
-- =============================================

-- If you prefer to keep RLS enabled but allow development inserts:
-- (Uncomment these if you want to use this approach instead)

/*
-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Users can insert their own user programs" ON user_programs;
DROP POLICY IF EXISTS "Users can insert their own program progress" ON program_progress;
DROP POLICY IF EXISTS "Users can insert their own workout completions" ON workout_completions;
DROP POLICY IF EXISTS "Users can insert their own weight progressions" ON weight_progressions;

-- Create permissive policies for development
CREATE POLICY "Allow development inserts" ON user_programs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow development program progress inserts" ON program_progress
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow development workout completion inserts" ON workout_completions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow development weight progression inserts" ON weight_progressions
    FOR INSERT WITH CHECK (true);
*/

-- =============================================
-- VERIFICATION
-- =============================================

-- Check if RLS is disabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('user_programs', 'program_progress', 'workout_completions', 'weight_progressions')
AND schemaname = 'public';

-- =============================================
-- RE-ENABLE FOR PRODUCTION
-- =============================================

-- When ready for production with proper authentication, run:
/*
ALTER TABLE user_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE program_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_progressions ENABLE ROW LEVEL SECURITY;

-- Then restore the original policies from SUPABASE_COMPLETE_SCHEMA.sql
*/
