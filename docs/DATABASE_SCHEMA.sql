-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.club_events (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  club_id uuid NOT NULL,
  created_by uuid NOT NULL,
  title text NOT NULL,
  start_time timestamp with time zone NOT NULL,
  location_lat double precision,
  location_long double precision,
  address_text text,
  meeting_point_description text,
  required_weight integer,
  water_requirements text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  description text,
  CONSTRAINT club_events_pkey PRIMARY KEY (id),
  CONSTRAINT club_events_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.club_members (
  club_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text DEFAULT 'member'::text CHECK (role = ANY (ARRAY['founder'::text, 'leader'::text, 'member'::text])),
  joined_at timestamp with time zone DEFAULT now(),
  waiver_signed_at timestamp with time zone,
  emergency_contact_json jsonb,
  CONSTRAINT club_members_pkey PRIMARY KEY (club_id, user_id),
  CONSTRAINT club_members_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.club_posts (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  club_id uuid,
  user_id uuid,
  post_type text DEFAULT 'workout'::text CHECK (post_type = ANY (ARRAY['workout'::text, 'text'::text, 'question'::text, 'event_comment'::text])),
  content text,
  workout_id uuid,
  distance_miles double precision,
  duration_minutes integer,
  weight_lbs double precision,
  calories integer,
  like_count integer DEFAULT 0,
  comment_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  elevation_gain double precision DEFAULT 0,
  event_id uuid,
  CONSTRAINT club_posts_pkey PRIMARY KEY (id),
  CONSTRAINT club_posts_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT club_posts_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.club_events(id)
);
CREATE TABLE public.clubs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  join_code text NOT NULL UNIQUE,
  created_by uuid,
  is_private boolean DEFAULT false,
  avatar_url text,
  member_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  zipcode text,
  latitude numeric,
  longitude numeric,
  CONSTRAINT clubs_pkey PRIMARY KEY (id),
  CONSTRAINT clubs_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.event_rsvps (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  event_id uuid NOT NULL,
  user_id uuid NOT NULL,
  status text NOT NULL CHECK (status = ANY (ARRAY['going'::text, 'maybe'::text, 'out'::text])),
  declared_weight integer,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT event_rsvps_pkey PRIMARY KEY (id),
  CONSTRAINT event_rsvps_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.club_events(id),
  CONSTRAINT event_rsvps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.global_leaderboard_entries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  week_start date NOT NULL,
  total_distance numeric DEFAULT 0,
  total_elevation numeric DEFAULT 0,
  total_tonnage numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT global_leaderboard_entries_pkey PRIMARY KEY (id),
  CONSTRAINT global_leaderboard_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.leaderboard_entries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  club_id uuid,
  user_id uuid,
  week_start date NOT NULL,
  total_distance numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  total_weight_carried numeric DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  total_elevation numeric DEFAULT 0,
  CONSTRAINT leaderboard_entries_pkey PRIMARY KEY (id),
  CONSTRAINT leaderboard_entries_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT leaderboard_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.post_likes (
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT post_likes_pkey PRIMARY KEY (post_id, user_id),
  CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.club_posts(id),
  CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text NOT NULL UNIQUE,
  display_name text,
  avatar_url text,
  bio text,
  location text,
  total_distance numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  current_streak integer DEFAULT 0,
  longest_streak integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  is_premium boolean DEFAULT false,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_badges (
  user_id uuid NOT NULL,
  badge_id text NOT NULL,
  awarded_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_badges_pkey PRIMARY KEY (user_id, badge_id),
  CONSTRAINT user_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.user_subscriptions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  subscription_type text NOT NULL CHECK (subscription_type = ANY (ARRAY['monthly'::text, 'yearly'::text, 'ambassador'::text])),
  status text NOT NULL CHECK (status = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text])),
  started_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone,
  apple_transaction_id text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.user_preferences (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  body_weight double precision DEFAULT 180.0,
  preferred_weight_unit text DEFAULT 'lbs',
  preferred_distance_unit text DEFAULT 'mi',
  default_ruck_weight double precision DEFAULT 20.0,
  rucking_goal text DEFAULT 'Longevity & Health',
  experience_level text DEFAULT 'New to Rucking',
  preferred_training_days integer[] DEFAULT '{2,4,7}',
  active_program_id text,
  target_event_date timestamp with time zone,
  baseline_pace_minutes_per_mile double precision DEFAULT 16.0,
  baseline_longest_distance_miles double precision DEFAULT 4.0,
  has_hill_access boolean DEFAULT true,
  has_stairs_access boolean DEFAULT false,
  injury_flags text[] DEFAULT '{}',
  has_completed_onboarding boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT user_preferences_user_id_key UNIQUE (user_id)
);
-- RLS for user_preferences: each user can only access their own row
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own preferences"
  ON public.user_preferences FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own preferences"
  ON public.user_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own preferences"
  ON public.user_preferences FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- RPC: get_club_feed
-- Returns club posts with author info and event title (if linked).
-- Run this in the Supabase SQL Editor to create/replace the function.
-- ============================================================
CREATE OR REPLACE FUNCTION get_club_feed(p_club_id UUID, p_limit INT DEFAULT 50)
RETURNS TABLE (
    id UUID,
    club_id UUID,
    user_id UUID,
    post_type TEXT,
    content TEXT,
    workout_id UUID,
    distance_miles DOUBLE PRECISION,
    duration_minutes INT,
    weight_lbs DOUBLE PRECISION,
    calories INT,
    elevation_gain DOUBLE PRECISION,
    like_count INT,
    comment_count INT,
    created_at TIMESTAMPTZ,
    author_id UUID,
    author_username TEXT,
    author_avatar_url TEXT,
    event_id UUID,
    event_title TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        cp.id,
        cp.club_id,
        cp.user_id,
        cp.post_type,
        cp.content,
        cp.workout_id,
        cp.distance_miles,
        cp.duration_minutes,
        cp.weight_lbs,
        cp.calories,
        cp.elevation_gain,
        cp.like_count,
        cp.comment_count,
        cp.created_at,
        p.id        AS author_id,
        p.username   AS author_username,
        p.avatar_url AS author_avatar_url,
        cp.event_id,
        ce.title     AS event_title
    FROM club_posts cp
    LEFT JOIN profiles p ON p.id = cp.user_id
    LEFT JOIN club_events ce ON ce.id = cp.event_id
    WHERE cp.club_id = p_club_id
    ORDER BY cp.created_at DESC
    LIMIT p_limit;
$$;