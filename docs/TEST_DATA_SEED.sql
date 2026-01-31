-- ============================================================================
-- TEST DATA SEED SCRIPT
-- ============================================================================
-- Populates the database with realistic test data for testing all features:
--   - 5 test users with different roles and subscription statuses
--   - 1 test club with all users as members
--   - Club events with RSVPs
--   - Workout posts in the club feed
--   - Badges awarded to users
--   - Weekly leaderboard entries
--
-- RUN THIS IN: Supabase SQL Editor
-- 
-- WARNING: This creates test data. Run on development/staging only!
-- ============================================================================

-- ============================================================================
-- STEP 0: ENSURE REQUIRED COLUMNS EXIST
-- ============================================================================
-- Add is_premium column if it doesn't exist (from BADGES_MIGRATION)

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

-- ============================================================================
-- STEP 0.5: GET OR CREATE TEST USER IDs
-- ============================================================================
-- This script uses existing auth users if they exist (by email),
-- otherwise creates temp table with the user IDs we'll use.
--
-- We store the user IDs in a temp table for use throughout the script.

CREATE TEMP TABLE IF NOT EXISTS test_user_ids (
    role_name TEXT PRIMARY KEY,
    user_id UUID
);

-- Clear any existing data
DELETE FROM test_user_ids;

-- Look up existing users by email, or we'll need to create them
INSERT INTO test_user_ids (role_name, user_id)
SELECT 'founder', id FROM auth.users WHERE email = 'founder@test.com'
UNION ALL
SELECT 'leader', id FROM auth.users WHERE email = 'leader@test.com'
UNION ALL
SELECT 'member', id FROM auth.users WHERE email = 'member@test.com'
UNION ALL
SELECT 'pro', id FROM auth.users WHERE email = 'pro@test.com'
UNION ALL
SELECT 'outsider', id FROM auth.users WHERE email = 'outsider@test.com';

-- Show what we found
SELECT 'Found existing users:' AS status;
SELECT * FROM test_user_ids;

-- ============================================================================
-- STEP 1: CREATE/UPDATE TEST USER PROFILES
-- ============================================================================
-- Uses the user IDs from the temp table (existing auth users)

-- Founder profile
INSERT INTO profiles (id, username, display_name, avatar_url, bio, location, total_distance, total_workouts, current_streak, longest_streak, is_premium, created_at)
SELECT 
    user_id,
    'founder_nick', 
    'Nick (Founder)', 
    NULL, 
    'Club founder and ruck enthusiast. Building the community one step at a time.',
    'San Diego, CA',
    156.7,
    42,
    5,
    14,
    false,
    NOW() - INTERVAL '90 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name,
    bio = EXCLUDED.bio,
    location = EXCLUDED.location,
    total_distance = EXCLUDED.total_distance,
    total_workouts = EXCLUDED.total_workouts,
    is_premium = EXCLUDED.is_premium;

-- Leader profile
INSERT INTO profiles (id, username, display_name, avatar_url, bio, location, total_distance, total_workouts, current_streak, longest_streak, is_premium, created_at)
SELECT 
    user_id,
    'leader_sarah', 
    'Sarah (Leader)', 
    NULL, 
    'Event coordinator and trail finder. Love heavy rucks!',
    'La Jolla, CA',
    89.3,
    28,
    3,
    7,
    false,
    NOW() - INTERVAL '60 days'
FROM test_user_ids WHERE role_name = 'leader'
ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name,
    bio = EXCLUDED.bio,
    location = EXCLUDED.location,
    total_distance = EXCLUDED.total_distance,
    total_workouts = EXCLUDED.total_workouts,
    is_premium = EXCLUDED.is_premium;

-- Member profile
INSERT INTO profiles (id, username, display_name, avatar_url, bio, location, total_distance, total_workouts, current_streak, longest_streak, is_premium, created_at)
SELECT 
    user_id,
    'member_jake', 
    'Jake', 
    NULL, 
    'Just getting into rucking. Training for my first GORUCK Light.',
    'Oceanside, CA',
    34.2,
    12,
    2,
    4,
    false,
    NOW() - INTERVAL '30 days'
FROM test_user_ids WHERE role_name = 'member'
ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name,
    bio = EXCLUDED.bio,
    location = EXCLUDED.location,
    total_distance = EXCLUDED.total_distance,
    total_workouts = EXCLUDED.total_workouts,
    is_premium = EXCLUDED.is_premium;

-- PRO profile
INSERT INTO profiles (id, username, display_name, avatar_url, bio, location, total_distance, total_workouts, current_streak, longest_streak, is_premium, created_at)
SELECT 
    user_id,
    'pro_maria', 
    'Maria (PRO)', 
    NULL, 
    'PRO athlete. Selection prep in progress. Heavy is good.',
    'Encinitas, CA',
    287.5,
    95,
    12,
    30,
    true,
    NOW() - INTERVAL '180 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name,
    bio = EXCLUDED.bio,
    location = EXCLUDED.location,
    total_distance = EXCLUDED.total_distance,
    total_workouts = EXCLUDED.total_workouts,
    is_premium = EXCLUDED.is_premium;

-- Outsider profile
INSERT INTO profiles (id, username, display_name, avatar_url, bio, location, total_distance, total_workouts, current_streak, longest_streak, is_premium, created_at)
SELECT 
    user_id,
    'outsider_tom', 
    'Tom', 
    NULL, 
    'Looking for a local ruck club to join.',
    'Carlsbad, CA',
    12.1,
    5,
    1,
    2,
    false,
    NOW() - INTERVAL '14 days'
FROM test_user_ids WHERE role_name = 'outsider'
ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name,
    bio = EXCLUDED.bio,
    location = EXCLUDED.location,
    total_distance = EXCLUDED.total_distance,
    total_workouts = EXCLUDED.total_workouts,
    is_premium = EXCLUDED.is_premium;

-- ============================================================================
-- STEP 2: CREATE TEST CLUB
-- ============================================================================

-- Test Club UUID
-- club: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa

INSERT INTO clubs (id, name, description, join_code, created_by, is_private, member_count, zipcode, latitude, longitude, created_at)
SELECT 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'San Diego Ruck Club',
    'The premier rucking community in San Diego. Weekly group rucks, training events, and GORUCK prep. All levels welcome!',
    'SDRC-2024',
    (SELECT user_id FROM test_user_ids WHERE role_name = 'founder'),
    false,
    4,
    '92101',
    32.7157,
    -117.1611,
    NOW() - INTERVAL '90 days'
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    join_code = EXCLUDED.join_code,
    member_count = EXCLUDED.member_count;

-- ============================================================================
-- STEP 3: ADD CLUB MEMBERS WITH ROLES
-- ============================================================================

-- Founder
INSERT INTO club_members (club_id, user_id, role, waiver_signed_at, emergency_contact_json, joined_at)
SELECT 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    user_id,
    'founder',
    NOW() - INTERVAL '90 days',
    '{"name": "Jane Dame", "phone": "619-555-0101"}',
    NOW() - INTERVAL '90 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (club_id, user_id) DO UPDATE SET
    role = EXCLUDED.role,
    waiver_signed_at = EXCLUDED.waiver_signed_at,
    emergency_contact_json = EXCLUDED.emergency_contact_json;

-- Leader
INSERT INTO club_members (club_id, user_id, role, waiver_signed_at, emergency_contact_json, joined_at)
SELECT 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    user_id,
    'leader',
    NOW() - INTERVAL '60 days',
    '{"name": "Mike Johnson", "phone": "619-555-0102"}',
    NOW() - INTERVAL '60 days'
FROM test_user_ids WHERE role_name = 'leader'
ON CONFLICT (club_id, user_id) DO UPDATE SET
    role = EXCLUDED.role,
    waiver_signed_at = EXCLUDED.waiver_signed_at,
    emergency_contact_json = EXCLUDED.emergency_contact_json;

-- Member
INSERT INTO club_members (club_id, user_id, role, waiver_signed_at, emergency_contact_json, joined_at)
SELECT 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    user_id,
    'member',
    NOW() - INTERVAL '30 days',
    '{"name": "Lisa Smith", "phone": "619-555-0103"}',
    NOW() - INTERVAL '30 days'
FROM test_user_ids WHERE role_name = 'member'
ON CONFLICT (club_id, user_id) DO UPDATE SET
    role = EXCLUDED.role,
    waiver_signed_at = EXCLUDED.waiver_signed_at,
    emergency_contact_json = EXCLUDED.emergency_contact_json;

-- PRO Member
INSERT INTO club_members (club_id, user_id, role, waiver_signed_at, emergency_contact_json, joined_at)
SELECT 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    user_id,
    'member',
    NOW() - INTERVAL '45 days',
    '{"name": "Carlos Garcia", "phone": "619-555-0104"}',
    NOW() - INTERVAL '45 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (club_id, user_id) DO UPDATE SET
    role = EXCLUDED.role,
    waiver_signed_at = EXCLUDED.waiver_signed_at,
    emergency_contact_json = EXCLUDED.emergency_contact_json;

-- Update member count
UPDATE clubs SET member_count = 4 WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- ============================================================================
-- STEP 4: CREATE CLUB EVENTS
-- ============================================================================

-- Event UUIDs
-- event1: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01 (past event)
-- event2: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02 (upcoming this week)
-- event3: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03 (upcoming next week)

-- Past event (completed last Saturday) - created by leader
INSERT INTO club_events (id, club_id, created_by, title, start_time, location_lat, location_long, address_text, meeting_point_description, required_weight, water_requirements, created_at)
SELECT 
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    user_id,
    'Saturday Morning Ruck - Balboa Park',
    (DATE_TRUNC('week', NOW()) - INTERVAL '2 days')::DATE + TIME '07:00',
    32.7341,
    -117.1446,
    'Balboa Park, San Diego, CA',
    'Meet at the Organ Pavilion parking lot. Look for the GORUCK flag.',
    20,
    'Bring at least 2L of water. It gets hot!',
    NOW() - INTERVAL '10 days'
FROM test_user_ids WHERE role_name = 'leader'
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    start_time = EXCLUDED.start_time,
    address_text = EXCLUDED.address_text;

-- Upcoming event (this Saturday) - created by founder
INSERT INTO club_events (id, club_id, created_by, title, start_time, location_lat, location_long, address_text, meeting_point_description, required_weight, water_requirements, created_at)
SELECT 
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    user_id,
    'Beach Ruck - Mission Beach',
    (DATE_TRUNC('week', NOW()) + INTERVAL '5 days')::DATE + TIME '06:30',
    32.7872,
    -117.2523,
    'Mission Beach, San Diego, CA',
    'Belmont Park parking lot. We''ll ruck to Pacific Beach and back.',
    30,
    'Heavy hydration required. 3L minimum.',
    NOW() - INTERVAL '3 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    start_time = EXCLUDED.start_time,
    address_text = EXCLUDED.address_text;

-- Future event (next Saturday) - created by leader
INSERT INTO club_events (id, club_id, created_by, title, start_time, location_lat, location_long, address_text, meeting_point_description, required_weight, water_requirements, created_at)
SELECT 
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    user_id,
    'Hill Repeats - Mt. Soledad',
    (DATE_TRUNC('week', NOW()) + INTERVAL '12 days')::DATE + TIME '07:00',
    32.8400,
    -117.2428,
    'Mt. Soledad, La Jolla, CA',
    'Kate Sessions Park lower lot. Prepare for pain.',
    35,
    'Bring electrolytes. This one hurts.',
    NOW() - INTERVAL '1 day'
FROM test_user_ids WHERE role_name = 'leader'
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    start_time = EXCLUDED.start_time,
    address_text = EXCLUDED.address_text;

-- ============================================================================
-- STEP 5: ADD EVENT RSVPs
-- ============================================================================

-- Past event RSVPs (everyone went)
INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', user_id, 'going', 35, NOW() - INTERVAL '8 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', user_id, 'going', 25, NOW() - INTERVAL '8 days'
FROM test_user_ids WHERE role_name = 'leader'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', user_id, 'going', 20, NOW() - INTERVAL '7 days'
FROM test_user_ids WHERE role_name = 'member'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', user_id, 'going', 45, NOW() - INTERVAL '9 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

-- Upcoming event RSVPs (mixed responses)
INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', user_id, 'going', 35, NOW() - INTERVAL '2 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', user_id, 'going', 30, NOW() - INTERVAL '2 days'
FROM test_user_ids WHERE role_name = 'leader'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', user_id, 'maybe', NULL, NOW() - INTERVAL '1 day'
FROM test_user_ids WHERE role_name = 'member'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', user_id, 'going', 50, NOW() - INTERVAL '1 day'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

-- Future event RSVPs (only founder and pro so far)
INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03', user_id, 'going', 40, NOW() - INTERVAL '12 hours'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

INSERT INTO event_rsvps (event_id, user_id, status, declared_weight, created_at)
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03', user_id, 'going', 45, NOW() - INTERVAL '6 hours'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (event_id, user_id) DO UPDATE SET status = EXCLUDED.status, declared_weight = EXCLUDED.declared_weight;

-- ============================================================================
-- STEP 6: CREATE WORKOUT POSTS (Club Feed Activity)
-- ============================================================================

-- Generate workout posts from the past 2 weeks
-- PRO Maria - heavy and consistent (7 workouts this week)
INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Selection prep day 45. Legs are toast but the mind is willing.', gen_random_uuid(), 8.2, 95, 55, 892, 1250, 12, 3, NOW() - INTERVAL '1 day'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Easy recovery ruck. Still counts!', gen_random_uuid(), 3.1, 42, 35, 245, 120, 5, 1, NOW() - INTERVAL '2 days'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Hill repeats at Torrey Pines. Beautiful sunrise.', gen_random_uuid(), 5.5, 78, 50, 623, 890, 8, 2, NOW() - INTERVAL '3 days'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', NULL, gen_random_uuid(), 6.8, 82, 45, 534, 320, 4, 0, NOW() - INTERVAL '4 days'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Long ruck day. Embrace the suck.', gen_random_uuid(), 12.4, 165, 55, 1245, 780, 15, 5, NOW() - INTERVAL '5 days'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', NULL, gen_random_uuid(), 4.2, 52, 40, 367, 210, 3, 0, NOW() - INTERVAL '6 days'
FROM test_user_ids WHERE role_name = 'pro';

-- Founder Nick - solid consistency (4 workouts this week)
INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Morning ruck before the kids wake up. Dad life.', gen_random_uuid(), 4.5, 55, 35, 378, 180, 7, 2, NOW() - INTERVAL '1 day'
FROM test_user_ids WHERE role_name = 'founder';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Beach ruck at sunset. This is why we live here.', gen_random_uuid(), 5.8, 72, 30, 423, 45, 11, 4, NOW() - INTERVAL '3 days'
FROM test_user_ids WHERE role_name = 'founder';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', NULL, gen_random_uuid(), 3.2, 40, 35, 287, 95, 2, 0, NOW() - INTERVAL '5 days'
FROM test_user_ids WHERE role_name = 'founder';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Group ruck was awesome! Great turnout.', gen_random_uuid(), 6.1, 78, 35, 489, 320, 9, 3, NOW() - INTERVAL '6 days'
FROM test_user_ids WHERE role_name = 'founder';

-- Leader Sarah - 3 workouts this week
INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Heavy Tuesday! Feeling strong', gen_random_uuid(), 4.8, 62, 40, 412, 240, 6, 1, NOW() - INTERVAL '2 days'
FROM test_user_ids WHERE role_name = 'leader';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', NULL, gen_random_uuid(), 3.5, 45, 30, 278, 150, 3, 0, NOW() - INTERVAL '4 days'
FROM test_user_ids WHERE role_name = 'leader';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Early bird gets the gains.', gen_random_uuid(), 5.2, 68, 35, 398, 280, 5, 2, NOW() - INTERVAL '6 days'
FROM test_user_ids WHERE role_name = 'leader';

-- Member Jake - 2 workouts this week (still building up)
INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'First ruck over 3 miles! Progress!', gen_random_uuid(), 3.2, 48, 20, 234, 85, 8, 4, NOW() - INTERVAL '2 days'
FROM test_user_ids WHERE role_name = 'member';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Slow and steady. Learning to love the weight.', gen_random_uuid(), 2.5, 38, 20, 189, 60, 4, 1, NOW() - INTERVAL '5 days'
FROM test_user_ids WHERE role_name = 'member';

-- Add some older posts for leaderboard variety (last week)
INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', NULL, gen_random_uuid(), 7.5, 92, 50, 756, 450, 6, 1, NOW() - INTERVAL '8 days'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', NULL, gen_random_uuid(), 5.8, 72, 45, 523, 320, 4, 0, NOW() - INTERVAL '9 days'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', 'Weekend warrior mode activated.', gen_random_uuid(), 8.2, 105, 35, 612, 520, 10, 3, NOW() - INTERVAL '8 days'
FROM test_user_ids WHERE role_name = 'founder';

INSERT INTO club_posts (id, club_id, user_id, post_type, content, workout_id, distance_miles, duration_minutes, weight_lbs, calories, elevation_gain, like_count, comment_count, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'workout', NULL, gen_random_uuid(), 4.1, 52, 35, 345, 180, 3, 0, NOW() - INTERVAL '9 days'
FROM test_user_ids WHERE role_name = 'leader';

-- ============================================================================
-- STEP 7: ADD EVENT COMMENTS (The Wire)
-- ============================================================================

-- Comments on upcoming beach ruck (event 02)
INSERT INTO club_posts (id, club_id, user_id, event_id, post_type, content, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', 'event_comment', 'Who''s bringing the camera? We need content for the gram!', NOW() - INTERVAL '2 days'
FROM test_user_ids WHERE role_name = 'founder';

INSERT INTO club_posts (id, club_id, user_id, event_id, post_type, content, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', 'event_comment', 'I''ll bring my GoPro. Sand ruck footage incoming.', NOW() - INTERVAL '1 day'
FROM test_user_ids WHERE role_name = 'leader';

INSERT INTO club_posts (id, club_id, user_id, event_id, post_type, content, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', 'event_comment', 'FYI the tide will be high at 7am. We might get wet feet!', NOW() - INTERVAL '12 hours'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, event_id, post_type, content, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', 'event_comment', 'Is 20lbs okay or should I go heavier?', NOW() - INTERVAL '6 hours'
FROM test_user_ids WHERE role_name = 'member';

INSERT INTO club_posts (id, club_id, user_id, event_id, post_type, content, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02', 'event_comment', '20lbs is perfect for a beach ruck. The sand adds resistance!', NOW() - INTERVAL '4 hours'
FROM test_user_ids WHERE role_name = 'founder';

-- Comments on hill repeats event (event 03)
INSERT INTO club_posts (id, club_id, user_id, event_id, post_type, content, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03', 'event_comment', 'This one is going to hurt. I''m in.', NOW() - INTERVAL '5 hours'
FROM test_user_ids WHERE role_name = 'pro';

INSERT INTO club_posts (id, club_id, user_id, event_id, post_type, content, created_at)
SELECT gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03', 'event_comment', 'Wear trail shoes. The path down gets slippery.', NOW() - INTERVAL '3 hours'
FROM test_user_ids WHERE role_name = 'founder';

-- ============================================================================
-- STEP 8: AWARD BADGES TO USERS
-- ============================================================================

-- PRO Maria - lots of achievements
INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, 'pro_athlete', NOW() - INTERVAL '180 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (user_id, badge_id) DO NOTHING;

INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, '100_mile_club', NOW() - INTERVAL '120 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (user_id, badge_id) DO NOTHING;

INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, 'heavy_hauler', NOW() - INTERVAL '90 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (user_id, badge_id) DO NOTHING;

INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, 'week_warrior', NOW() - INTERVAL '150 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (user_id, badge_id) DO NOTHING;

INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, 'month_master', NOW() - INTERVAL '60 days'
FROM test_user_ids WHERE role_name = 'pro'
ON CONFLICT (user_id, badge_id) DO NOTHING;

-- Founder Nick - founder badge + distance
INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, 'club_founder', NOW() - INTERVAL '85 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (user_id, badge_id) DO NOTHING;

INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, '100_mile_club', NOW() - INTERVAL '30 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (user_id, badge_id) DO NOTHING;

INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, 'week_warrior', NOW() - INTERVAL '45 days'
FROM test_user_ids WHERE role_name = 'founder'
ON CONFLICT (user_id, badge_id) DO NOTHING;

-- Leader Sarah - streak badge
INSERT INTO user_badges (user_id, badge_id, awarded_at)
SELECT user_id, 'week_warrior', NOW() - INTERVAL '20 days'
FROM test_user_ids WHERE role_name = 'leader'
ON CONFLICT (user_id, badge_id) DO NOTHING;

-- Member Jake - just starting out, no badges yet (intentionally empty)
-- Outsider Tom - also no badges (intentionally empty)

-- ============================================================================
-- STEP 9: UPDATE WEEKLY LEADERBOARD (if table exists)
-- ============================================================================

-- Note: This may not be needed if leaderboard is calculated via views
-- Uncomment if you have a weekly_leaderboard table that needs seeding

/*
INSERT INTO weekly_leaderboard (club_id, user_id, week_start, total_distance, total_elevation, total_workouts)
VALUES 
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', 
     DATE_TRUNC('week', NOW()), 40.2, 3790, 7),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 
     DATE_TRUNC('week', NOW()), 19.6, 640, 4),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 
     DATE_TRUNC('week', NOW()), 13.5, 670, 3),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 
     DATE_TRUNC('week', NOW()), 5.7, 145, 2)
ON CONFLICT (club_id, user_id, week_start) DO UPDATE SET
    total_distance = EXCLUDED.total_distance,
    total_elevation = EXCLUDED.total_elevation,
    total_workouts = EXCLUDED.total_workouts;
*/

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check test user IDs found
SELECT 'Test User IDs:' AS info;
SELECT * FROM test_user_ids;

-- Check profiles were created
SELECT 'Profiles:' AS info;
SELECT p.id, p.username, p.display_name, p.is_premium, p.total_distance 
FROM profiles p
JOIN test_user_ids t ON p.id = t.user_id;

-- Check club was created
SELECT 'Club:' AS info;
SELECT id, name, join_code, member_count FROM clubs 
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Check memberships
SELECT 'Memberships:' AS info;
SELECT cm.role, p.username, cm.waiver_signed_at IS NOT NULL AS has_waiver
FROM club_members cm
JOIN profiles p ON p.id = cm.user_id
WHERE cm.club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
ORDER BY cm.role;

-- Check events
SELECT 'Events:' AS info;
SELECT title, start_time, required_weight FROM club_events 
WHERE club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
ORDER BY start_time;

-- Check workout posts
SELECT 'Recent Posts:' AS info;
SELECT p.username, cp.distance_miles, cp.weight_lbs, cp.created_at
FROM club_posts cp
JOIN profiles p ON p.id = cp.user_id
WHERE cp.club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  AND cp.post_type = 'workout'
ORDER BY cp.created_at DESC
LIMIT 10;

-- Check badges
SELECT 'Badges:' AS info;
SELECT p.username, ub.badge_id, ub.awarded_at
FROM user_badges ub
JOIN profiles p ON p.id = ub.user_id
JOIN test_user_ids t ON p.id = t.user_id
ORDER BY p.username, ub.awarded_at;

-- Check global leaderboard (weekly distance)
SELECT 'Global Leaderboard (Weekly Distance):' AS info;
SELECT * FROM global_leaderboard_distance_weekly LIMIT 10;

-- Check global leaderboard (all-time tonnage)
SELECT 'Global Leaderboard (All-Time Tonnage):' AS info;
SELECT * FROM global_leaderboard_tonnage_alltime LIMIT 10;

-- ============================================================================
-- CLEANUP (if needed)
-- ============================================================================

/*
-- ============================================================================
-- CLEANUP - To remove all test data
-- ============================================================================
-- Run these queries to clean up the test data:

-- Delete badges for test users
DELETE FROM user_badges WHERE user_id IN (
    SELECT id FROM auth.users WHERE email IN (
        'founder@test.com', 'leader@test.com', 'member@test.com', 
        'pro@test.com', 'outsider@test.com'
    )
);

-- Delete club posts
DELETE FROM club_posts WHERE club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Delete event RSVPs
DELETE FROM event_rsvps WHERE event_id IN (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'
);

-- Delete events
DELETE FROM club_events WHERE club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Delete club members
DELETE FROM club_members WHERE club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Delete club
DELETE FROM clubs WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Note: Profiles and auth.users are NOT deleted here since they existed before
-- the seed script. Only delete those if you also want to remove the test accounts.
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

SELECT 'Test data seeded successfully!' AS status,
       (SELECT COUNT(*) FROM test_user_ids) AS test_users_found,
       (SELECT COUNT(*) FROM club_members WHERE club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') AS club_members,
       (SELECT COUNT(*) FROM club_events WHERE club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') AS events,
       (SELECT COUNT(*) FROM club_posts WHERE club_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') AS posts;

-- Clean up temp table
DROP TABLE IF EXISTS test_user_ids;
