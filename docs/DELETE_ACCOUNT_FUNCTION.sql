-- ============================================================
-- RPC: delete_user_account
--
-- Permanently deletes the calling user's account and all of
-- their data from MARCH.  Required by Apple App Store guideline
-- 5.1.1(v) — apps that allow account creation must provide
-- in-app account deletion.
--
-- Run this in the Supabase SQL Editor once.  The iOS client
-- invokes it via:
--     supabase.rpc("delete_user_account").execute()
--
-- Behaviour:
--   * Verifies the caller is authenticated (auth.uid()).
--   * For every club the user FOUNDED, the entire club tree
--     (post likes, posts, RSVPs, events, leaderboard rows,
--      members, and the club itself) is deleted — there is
--      no orphan ownership left behind.
--   * For every other club the user belongs to, only the user's
--     own data (memberships, posts, likes, RSVPs, events they
--     authored, leaderboard entries) is removed.  Posts and
--     RSVPs by OTHER users that referenced events the user
--     authored are also cleaned up so no FK violations occur.
--   * The user's profile, preferences, badges, subscriptions
--     and finally the auth.users row are deleted.
--
-- IMPORTANT — deletion order:
--   None of the public foreign keys have ON DELETE CASCADE,
--   so this function deletes children BEFORE parents in every
--   branch:
--      post_likes  →  club_posts  →  event_rsvps  →
--      club_events →  leaderboard_entries → club_members →
--      clubs       →  user_*    →  profiles → auth.users
--
-- Notes on Apple subscriptions:
--   The user_subscriptions row is removed, but App Store
--   subscriptions live on the Apple ID and CANNOT be cancelled
--   from a third-party server.  The client-side delete flow
--   tells the user to cancel via Settings ▸ Apple ID ▸
--   Subscriptions on their device.
-- ============================================================

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    uid uuid;
    founded_club_ids uuid[];
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- ----------------------------------------------------------
    -- 1. Clubs FOUNDED by this user — delete the full subtree.
    --    Children before parents:
    --      post_likes  →  club_posts  →  event_rsvps  →
    --      club_events →  leaderboard →  members      →  club
    -- ----------------------------------------------------------
    SELECT COALESCE(array_agg(id), '{}')
      INTO founded_club_ids
      FROM public.clubs
     WHERE created_by = uid;

    IF array_length(founded_club_ids, 1) > 0 THEN
        -- Likes on any post in these clubs
        DELETE FROM public.post_likes
         WHERE post_id IN (
             SELECT id FROM public.club_posts
              WHERE club_id = ANY(founded_club_ids)
         );

        -- All posts in these clubs.  MUST happen before club_events
        -- because club_posts.event_id references club_events(id).
        DELETE FROM public.club_posts
         WHERE club_id = ANY(founded_club_ids);

        -- RSVPs for events in these clubs
        DELETE FROM public.event_rsvps
         WHERE event_id IN (
             SELECT id FROM public.club_events
              WHERE club_id = ANY(founded_club_ids)
         );

        -- Events
        DELETE FROM public.club_events
         WHERE club_id = ANY(founded_club_ids);

        -- Leaderboard entries scoped to these clubs
        DELETE FROM public.leaderboard_entries
         WHERE club_id = ANY(founded_club_ids);

        -- All memberships in these clubs
        DELETE FROM public.club_members
         WHERE club_id = ANY(founded_club_ids);

        -- Finally the clubs themselves
        DELETE FROM public.clubs
         WHERE id = ANY(founded_club_ids);
    END IF;

    -- ----------------------------------------------------------
    -- 2. The user's own data in OTHER clubs (clubs they did
    --    NOT found, but participated in)
    -- ----------------------------------------------------------

    -- Likes the user gave on other people's posts
    DELETE FROM public.post_likes
     WHERE user_id = uid;

    -- Likes on posts authored by the user, then those posts.
    -- Must remove likes first because post_likes.post_id → club_posts.id.
    DELETE FROM public.post_likes
     WHERE post_id IN (
         SELECT id FROM public.club_posts WHERE user_id = uid
     );
    DELETE FROM public.club_posts
     WHERE user_id = uid;

    -- For events the user AUTHORED in other people's clubs:
    --   1. delete OTHER users' event-comment posts that reference them
    --      (and any likes on those posts)
    --   2. delete RSVPs to those events
    --   3. delete the events
    DELETE FROM public.post_likes
     WHERE post_id IN (
         SELECT cp.id
           FROM public.club_posts cp
           JOIN public.club_events ce ON ce.id = cp.event_id
          WHERE ce.created_by = uid
     );
    DELETE FROM public.club_posts
     WHERE event_id IN (
         SELECT id FROM public.club_events WHERE created_by = uid
     );
    DELETE FROM public.event_rsvps
     WHERE event_id IN (
         SELECT id FROM public.club_events WHERE created_by = uid
     );
    DELETE FROM public.club_events
     WHERE created_by = uid;

    -- RSVPs the user made to other people's events
    DELETE FROM public.event_rsvps
     WHERE user_id = uid;

    -- Memberships in clubs the user did not found
    DELETE FROM public.club_members
     WHERE user_id = uid;

    -- Leaderboard entries (club + global)
    DELETE FROM public.leaderboard_entries
     WHERE user_id = uid;
    DELETE FROM public.global_leaderboard_entries
     WHERE user_id = uid;

    -- Badges & subscriptions & preferences
    DELETE FROM public.user_badges
     WHERE user_id = uid;
    DELETE FROM public.user_subscriptions
     WHERE user_id = uid;
    DELETE FROM public.user_preferences
     WHERE user_id = uid;

    -- ----------------------------------------------------------
    -- 3. Profile + auth row
    -- ----------------------------------------------------------
    DELETE FROM public.profiles
     WHERE id = uid;

    DELETE FROM auth.users
     WHERE id = uid;
END;
$$;

-- Lock down execution: only authenticated users (acting on
-- their own behalf via auth.uid()) may invoke this function.
REVOKE ALL ON FUNCTION public.delete_user_account() FROM public;
REVOKE ALL ON FUNCTION public.delete_user_account() FROM anon;
GRANT  EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
