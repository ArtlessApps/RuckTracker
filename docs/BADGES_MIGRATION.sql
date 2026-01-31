-- ============================================================================
-- BADGES & GAMIFICATION MIGRATION
-- ============================================================================
-- This migration adds the gamification and badge system to RuckTracker.
-- 
-- Goals:
--   1. Retention: Award badges for milestones (Distance, Tonnage, Streaks)
--   2. Monetization: Display "PRO" badge on leaderboards to drive status-based upgrades
--
-- Changes:
--   1. Creates user_badges table for tracking earned achievements
--   2. Adds is_premium column to profiles for public PRO status display
--   3. Updates all global leaderboard views to include is_premium
--   4. Adds RLS policies for user_badges table
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE user_badges TABLE
-- Stores which badges each user has earned
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_badges (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    badge_id TEXT NOT NULL,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Primary key prevents duplicate badge awards
    CONSTRAINT user_badges_pkey PRIMARY KEY (user_id, badge_id)
);

-- Add index for efficient badge lookups by user
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id 
    ON user_badges (user_id);

-- Add index for finding all holders of a specific badge
CREATE INDEX IF NOT EXISTS idx_user_badges_badge_id 
    ON user_badges (badge_id);

-- Add comment for documentation
COMMENT ON TABLE user_badges IS 
    'Tracks which badges/achievements each user has earned. Badge definitions are in-app.';

-- ============================================================================
-- STEP 2: ADD is_premium COLUMN TO profiles
-- Publicly visible PRO status for leaderboard crown display
-- ============================================================================

-- Add the column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'is_premium'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN is_premium BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Add comment for documentation
COMMENT ON COLUMN public.profiles.is_premium IS 
    'Public PRO status flag. Synced from StoreKit subscription status. Used to show crown on leaderboards.';

-- ============================================================================
-- STEP 3: UPDATE LEADERBOARD VIEWS TO INCLUDE is_premium
-- All 4 global leaderboard views now select is_premium for crown display
-- ============================================================================

-- First, DROP the existing views (required because we're changing column order)
DROP VIEW IF EXISTS global_leaderboard_distance_weekly;
DROP VIEW IF EXISTS global_leaderboard_tonnage_alltime;
DROP VIEW IF EXISTS global_leaderboard_elevation_monthly;
DROP VIEW IF EXISTS global_leaderboard_consistency;

-- VIEW 1: Weekly Distance Leaderboard (updated with is_premium)
CREATE VIEW global_leaderboard_distance_weekly AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    COALESCE(SUM(cp.distance_miles), 0) AS score,
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(cp.distance_miles), 0) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
    AND cp.created_at >= date_trunc('week', CURRENT_DATE)
GROUP BY p.id, p.username, p.avatar_url, p.is_premium
HAVING COALESCE(SUM(cp.distance_miles), 0) > 0
ORDER BY rank ASC, p.username ASC;

COMMENT ON VIEW global_leaderboard_distance_weekly IS 
    'Weekly distance rankings with PRO status - resets every Monday. PRO feature.';

-- VIEW 2: All-Time Tonnage Leaderboard (updated with is_premium)
CREATE VIEW global_leaderboard_tonnage_alltime AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    COALESCE(SUM(cp.distance_miles * COALESCE(cp.weight_lbs, 0)), 0) AS score,
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(cp.distance_miles * COALESCE(cp.weight_lbs, 0)), 0) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
GROUP BY p.id, p.username, p.avatar_url, p.is_premium
HAVING COALESCE(SUM(cp.distance_miles * COALESCE(cp.weight_lbs, 0)), 0) > 0
ORDER BY rank ASC, p.username ASC;

COMMENT ON VIEW global_leaderboard_tonnage_alltime IS 
    'All-time "Heavy Haulers" tonnage rankings with PRO status (lbs-mi). PRO feature.';

-- VIEW 3: Monthly Elevation Leaderboard (updated with is_premium)
CREATE VIEW global_leaderboard_elevation_monthly AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    COALESCE(SUM(cp.elevation_gain), 0) AS score,
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(cp.elevation_gain), 0) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
    AND cp.created_at >= date_trunc('month', CURRENT_DATE)
GROUP BY p.id, p.username, p.avatar_url, p.is_premium
HAVING COALESCE(SUM(cp.elevation_gain), 0) > 0
ORDER BY rank ASC, p.username ASC;

COMMENT ON VIEW global_leaderboard_elevation_monthly IS 
    'Monthly elevation gain rankings with PRO status (feet). PRO feature.';

-- VIEW 4: Consistency Leaderboard (updated with is_premium)
CREATE VIEW global_leaderboard_consistency AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    COUNT(DISTINCT DATE(cp.created_at)) AS score,
    DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT DATE(cp.created_at)) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
    AND cp.created_at >= (CURRENT_DATE - INTERVAL '30 days')
GROUP BY p.id, p.username, p.avatar_url, p.is_premium
HAVING COUNT(DISTINCT DATE(cp.created_at)) > 0
ORDER BY rank ASC, p.username ASC;

COMMENT ON VIEW global_leaderboard_consistency IS 
    'Workout consistency rankings with PRO status - distinct workout days in last 30 days. PRO feature.';

-- ============================================================================
-- STEP 4: RLS POLICIES FOR user_badges
-- ============================================================================

-- Enable RLS on user_badges table
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotent re-runs)
DROP POLICY IF EXISTS "user_badges_select_authenticated" ON public.user_badges;
DROP POLICY IF EXISTS "user_badges_insert_own" ON public.user_badges;
DROP POLICY IF EXISTS "user_badges_delete_service" ON public.user_badges;

-- Policy: Anyone authenticated can view badges (public achievement display)
CREATE POLICY "user_badges_select_authenticated" ON public.user_badges
    FOR SELECT
    TO authenticated
    USING (true);

-- Policy: Service role can insert badges (prevents client-side cheating)
-- For MVP, we also allow authenticated users to insert their own badges
-- This should be tightened to service_role only in production with server-side validation
CREATE POLICY "user_badges_insert_own" ON public.user_badges
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Policy: Service role can delete badges (for admin corrections)
CREATE POLICY "user_badges_delete_service" ON public.user_badges
    FOR DELETE
    TO service_role
    USING (true);

-- Grant SELECT on views to authenticated users
GRANT SELECT ON global_leaderboard_distance_weekly TO authenticated;
GRANT SELECT ON global_leaderboard_tonnage_alltime TO authenticated;
GRANT SELECT ON global_leaderboard_elevation_monthly TO authenticated;
GRANT SELECT ON global_leaderboard_consistency TO authenticated;

-- Grant permissions on user_badges table
GRANT SELECT, INSERT ON public.user_badges TO authenticated;
GRANT ALL ON public.user_badges TO service_role;

-- ============================================================================
-- BADGE ID REFERENCE (defined in-app BadgeCatalog)
-- ============================================================================
-- 
-- Achievement Badges:
--   'pro_athlete'        - PRO subscription holder (Gold/Yellow, crown.fill)
--   '100_mile_club'      - Completed 100+ total miles (Bronze, shoeprints.fill)
--   'heavy_hauler'       - Achieved 10,000+ lbs-mi tonnage (Orange, dumbbell.fill)
--   'the_sherpa'         - Gained 50,000+ ft elevation (Purple, mountain.2.fill)
--   'selection_ready'    - Completed GORUCK Selection Prep program (Red, flame.fill)
--
-- Streak Badges (future):
--   'week_warrior'       - 7-day workout streak
--   'month_master'       - 30-day workout streak
--   'consistency_king'   - 100+ workout days in a year
--
-- ============================================================================

-- ============================================================================
-- VERIFICATION QUERIES (run these to test the migration)
-- ============================================================================

-- Test user_badges table:
-- SELECT * FROM user_badges LIMIT 10;

-- Test is_premium column:
-- SELECT id, username, is_premium FROM profiles LIMIT 10;

-- Test updated views include is_premium:
-- SELECT user_id, username, is_premium, score, rank FROM global_leaderboard_distance_weekly LIMIT 5;
-- SELECT user_id, username, is_premium, score, rank FROM global_leaderboard_tonnage_alltime LIMIT 5;
-- SELECT user_id, username, is_premium, score, rank FROM global_leaderboard_elevation_monthly LIMIT 5;
-- SELECT user_id, username, is_premium, score, rank FROM global_leaderboard_consistency LIMIT 5;

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
-- 
-- DROP POLICY IF EXISTS "user_badges_select_authenticated" ON public.user_badges;
-- DROP POLICY IF EXISTS "user_badges_insert_own" ON public.user_badges;
-- DROP POLICY IF EXISTS "user_badges_delete_service" ON public.user_badges;
-- DROP TABLE IF EXISTS public.user_badges;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_premium;
-- 
-- Then re-run GLOBAL_LEADERBOARD_MIGRATION.sql to restore original views
-- ============================================================================
