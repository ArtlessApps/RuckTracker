-- ============================================================================
-- REMOVE DISPLAY_NAME MIGRATION
-- ============================================================================
-- This migration:
-- 1. Updates the profile creation trigger to only use username
-- 2. Removes the display_name column from profiles table
-- 3. Updates database functions that reference display_name
--
-- RUN THIS IN: Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================================

-- ============================================================================
-- STEP 1: Update or create the profile trigger (username only)
-- ============================================================================

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create the function that handles new user signups (username only)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_username TEXT;
BEGIN
    -- Extract username from signup metadata
    v_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        -- Fallback: generate from email prefix if no username provided
        SPLIT_PART(NEW.email, '@', 1)
    );
    
    -- Ensure username is unique by appending random suffix if needed
    WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = v_username) LOOP
        v_username := v_username || '_' || SUBSTR(MD5(RANDOM()::TEXT), 1, 4);
    END LOOP;
    
    -- Insert the new profile (without display_name)
    INSERT INTO public.profiles (
        id,
        username,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        v_username,
        NOW(),
        NOW()
    );
    
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        -- If we still hit a race condition, append timestamp
        v_username := v_username || '_' || EXTRACT(EPOCH FROM NOW())::INT::TEXT;
        INSERT INTO public.profiles (
            id,
            username,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            v_username,
            NOW(),
            NOW()
        );
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on auth.users table
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- STEP 2: Remove display_name column from profiles
-- ============================================================================

-- First, make the column nullable if it isn't already
ALTER TABLE public.profiles ALTER COLUMN display_name DROP NOT NULL;

-- Then drop the column (commented out - uncomment when ready)
-- WARNING: This is destructive! Make sure all code is updated first.
-- ALTER TABLE public.profiles DROP COLUMN display_name;

-- ============================================================================
-- STEP 3: Update the get_club_feed function to not return display_name
-- ============================================================================
-- If you have a get_club_feed RPC function, update it to not return 
-- author_display_name. The app now only uses author_username.

-- Example (adjust based on your actual function):
-- CREATE OR REPLACE FUNCTION get_club_feed(p_club_id UUID)
-- RETURNS TABLE (
--     id UUID,
--     club_id UUID,
--     user_id UUID,
--     post_type TEXT,
--     content TEXT,
--     workout_id UUID,
--     distance_miles DOUBLE PRECISION,
--     duration_minutes INTEGER,
--     weight_lbs DOUBLE PRECISION,
--     calories INTEGER,
--     elevation_gain DOUBLE PRECISION,
--     like_count INTEGER,
--     comment_count INTEGER,
--     created_at TIMESTAMPTZ,
--     author_id UUID,
--     author_username TEXT,
--     author_avatar_url TEXT
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         cp.id,
--         cp.club_id,
--         cp.user_id,
--         cp.post_type,
--         cp.content,
--         cp.workout_id,
--         cp.distance_miles,
--         cp.duration_minutes,
--         cp.weight_lbs,
--         cp.calories,
--         cp.elevation_gain,
--         cp.like_count,
--         cp.comment_count,
--         cp.created_at,
--         p.id AS author_id,
--         p.username AS author_username,
--         p.avatar_url AS author_avatar_url
--     FROM club_posts cp
--     LEFT JOIN profiles p ON cp.user_id = p.id
--     WHERE cp.club_id = p_club_id
--     ORDER BY cp.created_at DESC;
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 4: Update test user profiles (if using seeded test data)
-- ============================================================================

-- Update test accounts to ensure they have usernames
UPDATE public.profiles SET username = 'founder_nick' 
WHERE id = (SELECT id FROM auth.users WHERE email = 'founder@test.com');

UPDATE public.profiles SET username = 'leader_sarah' 
WHERE id = (SELECT id FROM auth.users WHERE email = 'leader@test.com');

UPDATE public.profiles SET username = 'member_jake' 
WHERE id = (SELECT id FROM auth.users WHERE email = 'member@test.com');

UPDATE public.profiles SET username = 'pro_maria' 
WHERE id = (SELECT id FROM auth.users WHERE email = 'pro@test.com');

UPDATE public.profiles SET username = 'outsider_tom' 
WHERE id = (SELECT id FROM auth.users WHERE email = 'outsider@test.com');

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check profiles table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check trigger exists
SELECT tgname, tgrelid::regclass, tgtype 
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';
