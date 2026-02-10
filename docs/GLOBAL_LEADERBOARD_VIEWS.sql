-- ============================================================
-- GLOBAL LEADERBOARD: Views, Update Function & Seed Data
-- ============================================================
-- Run this in the Supabase SQL Editor to create the 4 global
-- leaderboard views and the RPC function that populates them.
-- ============================================================

-- 1. FUNCTION: update_global_leaderboard_entry
-- Called from the iOS app after every workout to upsert the
-- user's aggregated stats into global_leaderboard_entries.
-- ============================================================
CREATE OR REPLACE FUNCTION update_global_leaderboard_entry(
    p_user_id UUID,
    p_distance NUMERIC,
    p_elevation NUMERIC,
    p_tonnage NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_week_start DATE;
BEGIN
    -- Calculate the Monday of the current week
    v_week_start := date_trunc('week', CURRENT_DATE)::date;

    INSERT INTO global_leaderboard_entries (
        user_id, week_start, total_distance, total_elevation, total_tonnage, total_workouts, updated_at
    )
    VALUES (
        p_user_id, v_week_start, p_distance, p_elevation, p_tonnage, 1, now()
    )
    ON CONFLICT (user_id, week_start)
    DO UPDATE SET
        total_distance  = global_leaderboard_entries.total_distance  + EXCLUDED.total_distance,
        total_elevation = global_leaderboard_entries.total_elevation + EXCLUDED.total_elevation,
        total_tonnage   = global_leaderboard_entries.total_tonnage   + EXCLUDED.total_tonnage,
        total_workouts  = global_leaderboard_entries.total_workouts  + 1,
        updated_at      = now();
END;
$$;

-- NOTE: The function above requires a UNIQUE constraint on (user_id, week_start).
-- If it doesn't already exist, add it:
ALTER TABLE global_leaderboard_entries
    ADD CONSTRAINT global_leaderboard_entries_user_week_unique
    UNIQUE (user_id, week_start);

-- ============================================================
-- 2. DROP existing views so column types can be changed
-- ============================================================
DROP VIEW IF EXISTS global_leaderboard_distance_weekly;
DROP VIEW IF EXISTS global_leaderboard_tonnage_alltime;
DROP VIEW IF EXISTS global_leaderboard_elevation_monthly;
DROP VIEW IF EXISTS global_leaderboard_consistency;

-- ============================================================
-- 3. VIEW: global_leaderboard_distance_weekly
-- "Road Warriors" — Sum of miles THIS WEEK (resets Monday)
-- ============================================================
CREATE VIEW global_leaderboard_distance_weekly AS
SELECT
    gle.user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    gle.total_distance::double precision AS score,
    ROW_NUMBER() OVER (ORDER BY gle.total_distance DESC) AS rank
FROM global_leaderboard_entries gle
JOIN profiles p ON p.id = gle.user_id
WHERE gle.week_start = date_trunc('week', CURRENT_DATE)::date
  AND gle.total_distance > 0
ORDER BY rank;

-- ============================================================
-- 4. VIEW: global_leaderboard_tonnage_alltime
-- "Heavy Haulers" — Sum of lbs-mi ALL TIME (never resets)
-- ============================================================
CREATE VIEW global_leaderboard_tonnage_alltime AS
SELECT
    gle.user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    SUM(gle.total_tonnage)::double precision AS score,
    ROW_NUMBER() OVER (ORDER BY SUM(gle.total_tonnage) DESC) AS rank
FROM global_leaderboard_entries gle
JOIN profiles p ON p.id = gle.user_id
GROUP BY gle.user_id, p.username, p.avatar_url, p.is_premium
HAVING SUM(gle.total_tonnage) > 0
ORDER BY rank;

-- ============================================================
-- 5. VIEW: global_leaderboard_elevation_monthly
-- "Vertical Gainers" — Sum of ft gained THIS MONTH (resets 1st)
-- ============================================================
CREATE VIEW global_leaderboard_elevation_monthly AS
SELECT
    gle.user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    SUM(gle.total_elevation)::double precision AS score,
    ROW_NUMBER() OVER (ORDER BY SUM(gle.total_elevation) DESC) AS rank
FROM global_leaderboard_entries gle
JOIN profiles p ON p.id = gle.user_id
WHERE gle.week_start >= date_trunc('month', CURRENT_DATE)::date
  AND gle.total_elevation > 0
GROUP BY gle.user_id, p.username, p.avatar_url, p.is_premium
ORDER BY rank;

-- ============================================================
-- 6. VIEW: global_leaderboard_consistency
-- "Iron Discipline" — Distinct workout days in rolling 30 days
-- ============================================================
CREATE VIEW global_leaderboard_consistency AS
SELECT
    gle.user_id,
    p.username,
    p.avatar_url,
    p.is_premium,
    SUM(gle.total_workouts)::double precision AS score,
    ROW_NUMBER() OVER (ORDER BY SUM(gle.total_workouts) DESC) AS rank
FROM global_leaderboard_entries gle
JOIN profiles p ON p.id = gle.user_id
WHERE gle.week_start >= (CURRENT_DATE - INTERVAL '30 days')::date
  AND gle.total_workouts > 0
GROUP BY gle.user_id, p.username, p.avatar_url, p.is_premium
ORDER BY rank;

-- ============================================================
-- 6. RLS: Allow authenticated users to read the views
-- ============================================================
-- Views inherit the RLS of their underlying tables.
-- Ensure global_leaderboard_entries has a SELECT policy:
ALTER TABLE global_leaderboard_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read global leaderboard"
    ON global_leaderboard_entries
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow the update function (SECURITY DEFINER) to insert/update:
CREATE POLICY "Service can upsert global leaderboard entries"
    ON global_leaderboard_entries
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================
-- 7. SEED DATA FOR TESTING
-- Run this to populate test entries for the current week/month
-- so all 4 leaderboard capsules show data.
-- Replace the UUIDs below with real user IDs from your profiles table.
-- ============================================================

-- To get test user IDs:
-- SELECT id, username FROM profiles WHERE username IN ('pro_user', 'testuser', ...);

-- Example seed (uses current week_start automatically):
/*
INSERT INTO global_leaderboard_entries (user_id, week_start, total_distance, total_elevation, total_tonnage, total_workouts)
VALUES
    -- Replace these UUIDs with actual user IDs from your profiles table
    ('USER_UUID_1', date_trunc('week', CURRENT_DATE)::date, 12.5, 850, 312.5, 3),
    ('USER_UUID_2', date_trunc('week', CURRENT_DATE)::date, 8.3,  420, 207.5, 2),
    ('USER_UUID_3', date_trunc('week', CURRENT_DATE)::date, 15.1, 1200, 453.0, 4),
    ('USER_UUID_4', date_trunc('week', CURRENT_DATE)::date, 6.0,  300, 150.0, 2),
    ('USER_UUID_5', date_trunc('week', CURRENT_DATE)::date, 22.0, 1800, 660.0, 5)
ON CONFLICT (user_id, week_start) DO UPDATE SET
    total_distance  = EXCLUDED.total_distance,
    total_elevation = EXCLUDED.total_elevation,
    total_tonnage   = EXCLUDED.total_tonnage,
    total_workouts  = EXCLUDED.total_workouts,
    updated_at      = now();
*/
