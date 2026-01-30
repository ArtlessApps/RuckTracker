-- ============================================================================
-- GLOBAL LEADERBOARDS MIGRATION
-- ============================================================================
-- This migration creates 4 SQL views for global leaderboard rankings.
-- These are PRO-only features gated in the app layer.
--
-- Views created:
--   1. global_leaderboard_distance_weekly   - Weekly distance rankings
--   2. global_leaderboard_tonnage_alltime   - All-time tonnage (distance × weight)
--   3. global_leaderboard_elevation_monthly - Monthly elevation gain rankings
--   4. global_leaderboard_consistency       - Workout consistency (last 30 days)
-- ============================================================================

-- ============================================================================
-- VIEW 1: Weekly Distance Leaderboard
-- Ranks users by total distance (miles) for the current week (Monday start)
-- ============================================================================
CREATE OR REPLACE VIEW global_leaderboard_distance_weekly AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    COALESCE(SUM(cp.distance_miles), 0) AS score,
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(cp.distance_miles), 0) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
    AND cp.created_at >= date_trunc('week', CURRENT_DATE)
GROUP BY p.id, p.username, p.avatar_url
HAVING COALESCE(SUM(cp.distance_miles), 0) > 0
ORDER BY rank ASC, p.username ASC;

-- Add comment for documentation
COMMENT ON VIEW global_leaderboard_distance_weekly IS 
    'Weekly distance rankings - resets every Monday. PRO feature.';

-- ============================================================================
-- VIEW 2: All-Time Tonnage Leaderboard
-- Ranks users by total tonnage (distance_miles × ruck_weight_lbs)
-- This is "Heavy Haulers" - the ultimate ruck grind metric
-- ============================================================================
CREATE OR REPLACE VIEW global_leaderboard_tonnage_alltime AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    COALESCE(SUM(cp.distance_miles * COALESCE(cp.weight_lbs, 0)), 0) AS score,
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(cp.distance_miles * COALESCE(cp.weight_lbs, 0)), 0) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
GROUP BY p.id, p.username, p.avatar_url
HAVING COALESCE(SUM(cp.distance_miles * COALESCE(cp.weight_lbs, 0)), 0) > 0
ORDER BY rank ASC, p.username ASC;

-- Add comment for documentation
COMMENT ON VIEW global_leaderboard_tonnage_alltime IS 
    'All-time "Heavy Haulers" tonnage rankings (lbs-mi). PRO feature.';

-- ============================================================================
-- VIEW 3: Monthly Elevation Leaderboard
-- Ranks users by total elevation gain (feet) for the current month
-- This is "Vertical Gainers" - for the hill climbers
-- ============================================================================
CREATE OR REPLACE VIEW global_leaderboard_elevation_monthly AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    COALESCE(SUM(cp.elevation_gain), 0) AS score,
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(cp.elevation_gain), 0) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
    AND cp.created_at >= date_trunc('month', CURRENT_DATE)
GROUP BY p.id, p.username, p.avatar_url
HAVING COALESCE(SUM(cp.elevation_gain), 0) > 0
ORDER BY rank ASC, p.username ASC;

-- Add comment for documentation
COMMENT ON VIEW global_leaderboard_elevation_monthly IS 
    'Monthly elevation gain rankings (feet). PRO feature.';

-- ============================================================================
-- VIEW 4: Consistency Leaderboard (Last 30 Days)
-- Ranks users by number of distinct days with a workout in the last 30 days
-- This is "Iron Discipline" - showing up matters
-- ============================================================================
CREATE OR REPLACE VIEW global_leaderboard_consistency AS
SELECT 
    p.id AS user_id,
    p.username,
    p.avatar_url,
    COUNT(DISTINCT DATE(cp.created_at)) AS score,
    DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT DATE(cp.created_at)) DESC) AS rank
FROM profiles p
LEFT JOIN club_posts cp ON cp.user_id = p.id 
    AND cp.post_type = 'workout'
    AND cp.created_at >= (CURRENT_DATE - INTERVAL '30 days')
GROUP BY p.id, p.username, p.avatar_url
HAVING COUNT(DISTINCT DATE(cp.created_at)) > 0
ORDER BY rank ASC, p.username ASC;

-- Add comment for documentation
COMMENT ON VIEW global_leaderboard_consistency IS 
    'Workout consistency rankings - distinct workout days in last 30 days. PRO feature.';

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- These indexes help the views perform efficiently
-- ============================================================================

-- Index for efficient weekly/monthly filtering
CREATE INDEX IF NOT EXISTS idx_club_posts_workout_created 
    ON club_posts (created_at) 
    WHERE post_type = 'workout';

-- Composite index for leaderboard calculations
CREATE INDEX IF NOT EXISTS idx_club_posts_user_workout 
    ON club_posts (user_id, post_type, created_at) 
    WHERE post_type = 'workout';

-- ============================================================================
-- RLS POLICIES (if not already enabled)
-- Views inherit RLS from underlying tables, but we need SELECT on views
-- ============================================================================

-- Grant SELECT on views to authenticated users
-- (Views are read-only by nature)
GRANT SELECT ON global_leaderboard_distance_weekly TO authenticated;
GRANT SELECT ON global_leaderboard_tonnage_alltime TO authenticated;
GRANT SELECT ON global_leaderboard_elevation_monthly TO authenticated;
GRANT SELECT ON global_leaderboard_consistency TO authenticated;

-- ============================================================================
-- VERIFICATION QUERIES (run these to test the views)
-- ============================================================================

-- Test weekly distance:
-- SELECT * FROM global_leaderboard_distance_weekly LIMIT 10;

-- Test all-time tonnage:
-- SELECT * FROM global_leaderboard_tonnage_alltime LIMIT 10;

-- Test monthly elevation:
-- SELECT * FROM global_leaderboard_elevation_monthly LIMIT 10;

-- Test consistency:
-- SELECT * FROM global_leaderboard_consistency LIMIT 10;
