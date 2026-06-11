-- ============================================================
-- Fix: Apple sign-in skipping username picker
--
-- Problem:
--   The handle_new_user() trigger had an email-prefix fallback
--   that auto-assigned a username (e.g. "john" from john@example.com)
--   to every new user, including Apple sign-in users who have no
--   username in their metadata. This made needsUsername return false
--   and skipped the username picker entirely.
--
-- Fix:
--   If no username is present in raw_user_meta_data, skip the INSERT.
--   Apple sign-in users get their profile row created later via the
--   app's setUsernameAfterAppleSignIn() → upsert flow.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_username TEXT;
BEGIN
    v_username := trim(NEW.raw_user_meta_data->>'username');

    -- Only create the profile row when a username was explicitly provided
    -- in signup metadata (email/password path). Apple sign-in users have
    -- no username in metadata — their profile is created later by the app
    -- when the user picks a username in the "One last thing" screen.
    IF v_username IS NULL OR v_username = '' THEN
        RETURN NEW;
    END IF;

    INSERT INTO public.profiles (id, username)
    VALUES (NEW.id, v_username)
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;
