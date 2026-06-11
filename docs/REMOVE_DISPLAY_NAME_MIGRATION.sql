-- ============================================================
-- Migration: Remove display_name + install profile creation trigger
--
-- Run this once in the Supabase SQL Editor.
--
-- What it does:
--   1. Drops the unused display_name column from profiles
--   2. Creates (or replaces) the trigger that auto-creates a
--      profiles row whenever a new auth.users row is inserted.
--      The trigger reads username from signup metadata.
-- ============================================================

-- 1. Drop display_name (it has always been NULL — never written or read by the app)
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS display_name;

-- 2. Helper function called by the trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_username TEXT;
BEGIN
    -- Username comes from the data dict passed to supabase.auth.signUp()
    v_username := NEW.raw_user_meta_data->>'username';

    -- Fallback: derive something from the email if metadata is missing
    IF v_username IS NULL OR trim(v_username) = '' THEN
        v_username := split_part(NEW.email, '@', 1);
    END IF;

    v_username := trim(v_username);

    INSERT INTO public.profiles (id, username)
    VALUES (NEW.id, v_username)
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

-- 3. Username availability check for signup flows (callable by anon)
CREATE OR REPLACE FUNCTION public.is_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT NOT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE username = trim(p_username)
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_username_available(TEXT) TO anon, authenticated;

-- 4. Attach the trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
