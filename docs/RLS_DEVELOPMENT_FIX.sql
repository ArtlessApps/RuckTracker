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
-- COMMUNITY TABLES: Enable RLS with Proper Policies
-- =============================================

-- 1. PROFILES - Everyone can read, users can update their own
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" ON profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
CREATE POLICY "Users can insert their own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 2. CLUBS - Everyone can read, authenticated users can create
ALTER TABLE clubs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clubs are viewable by everyone" ON clubs;
CREATE POLICY "Clubs are viewable by everyone" ON clubs
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can create clubs" ON clubs;
CREATE POLICY "Authenticated users can create clubs" ON clubs
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Club creators can update their clubs" ON clubs;
CREATE POLICY "Club creators can update their clubs" ON clubs
    FOR UPDATE USING (auth.uid() = created_by);

-- 3. CLUB_MEMBERS - Members can see their clubs, users can join/leave
ALTER TABLE club_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view club memberships" ON club_members;
CREATE POLICY "Users can view club memberships" ON club_members
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can join clubs" ON club_members;
CREATE POLICY "Users can join clubs" ON club_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can leave clubs" ON club_members;
CREATE POLICY "Users can leave clubs" ON club_members
    FOR DELETE USING (auth.uid() = user_id);

-- 4. CLUB_POSTS - Members can read posts in their clubs, users can create posts
ALTER TABLE club_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view posts in their clubs" ON club_posts;
CREATE POLICY "Users can view posts in their clubs" ON club_posts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM club_members 
            WHERE club_members.club_id = club_posts.club_id 
            AND club_members.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can create posts in their clubs" ON club_posts;
CREATE POLICY "Users can create posts in their clubs" ON club_posts
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM club_members 
            WHERE club_members.club_id = club_posts.club_id 
            AND club_members.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete their own posts" ON club_posts;
CREATE POLICY "Users can delete their own posts" ON club_posts
    FOR DELETE USING (auth.uid() = user_id);

-- 5. POST_LIKES - Members can like/unlike posts in their clubs
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view likes" ON post_likes;
CREATE POLICY "Users can view likes" ON post_likes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can like posts" ON post_likes;
CREATE POLICY "Users can like posts" ON post_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unlike posts" ON post_likes;
CREATE POLICY "Users can unlike posts" ON post_likes
    FOR DELETE USING (auth.uid() = user_id);

-- 6. LEADERBOARD_ENTRIES - Members can view their club leaderboards
ALTER TABLE leaderboard_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view leaderboard entries" ON leaderboard_entries;
CREATE POLICY "Users can view leaderboard entries" ON leaderboard_entries
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM club_members 
            WHERE club_members.club_id = leaderboard_entries.club_id 
            AND club_members.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert/update their leaderboard entries" ON leaderboard_entries;
CREATE POLICY "Users can insert/update their leaderboard entries" ON leaderboard_entries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their leaderboard entries" ON leaderboard_entries;
CREATE POLICY "Users can update their leaderboard entries" ON leaderboard_entries
    FOR UPDATE USING (auth.uid() = user_id);

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

-- Check RLS status for all tables
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN (
    'user_programs', 'program_progress', 'workout_completions', 'weight_progressions',
    'profiles', 'clubs', 'club_members', 'club_posts', 'post_likes', 'leaderboard_entries'
)
AND schemaname = 'public';

-- List all RLS policies for community tables
SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' 
AND tablename IN ('profiles', 'clubs', 'club_members', 'club_posts', 'post_likes', 'leaderboard_entries')
ORDER BY tablename, policyname;

-- =============================================
-- ALTERNATIVE: DISABLE RLS FOR COMMUNITY TABLES (Quick Dev Fix)
-- =============================================
-- If the policies above still cause issues, you can temporarily disable RLS:
/*
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE clubs DISABLE ROW LEVEL SECURITY;
ALTER TABLE club_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE club_posts DISABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes DISABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard_entries DISABLE ROW LEVEL SECURITY;
*/

-- =============================================
-- RE-ENABLE FOR PRODUCTION
-- =============================================

-- When ready for production with proper authentication, run:
/*
ALTER TABLE user_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE program_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_progressions ENABLE ROW LEVEL SECURITY;

-- Community tables should already have RLS enabled with proper policies
-- See the COMMUNITY TABLES section above
*/
