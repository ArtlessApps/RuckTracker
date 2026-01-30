-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.club_events (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  start_time timestamp with time zone NOT NULL,
  club_id uuid NOT NULL,
  required_weight integer,
  water_requirements text,
  location_long double precision,
  meeting_point_description text,
  created_by uuid NOT NULL,
  title text NOT NULL,
  location_lat double precision,
  address_text text,
  CONSTRAINT club_events_pkey PRIMARY KEY (id),
  CONSTRAINT club_events_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.club_members (
  role text DEFAULT 'member'::text CHECK (role = ANY (ARRAY['founder'::text, 'leader'::text, 'member'::text])),
  joined_at timestamp with time zone DEFAULT now(),
  emergency_contact_json jsonb,
  club_id uuid NOT NULL,
  user_id uuid NOT NULL,
  waiver_signed_at timestamp with time zone,
  CONSTRAINT club_members_pkey PRIMARY KEY (club_id, user_id),
  CONSTRAINT club_members_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.club_posts (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  post_type text DEFAULT 'workout'::text CHECK (post_type = ANY (ARRAY['workout'::text, 'text'::text, 'question'::text, 'event_comment'::text])),
  like_count integer DEFAULT 0,
  comment_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  elevation_gain double precision DEFAULT 0,
  duration_minutes integer,
  workout_id uuid,
  user_id uuid,
  weight_lbs double precision,
  distance_miles double precision,
  calories integer,
  club_id uuid,
  event_id uuid,
  content text,
  CONSTRAINT club_posts_pkey PRIMARY KEY (id),
  CONSTRAINT club_posts_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT club_posts_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.club_events(id)
);
CREATE TABLE public.clubs (
  member_count integer DEFAULT 0,
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  is_private boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  name text NOT NULL,
  created_by uuid,
  join_code text NOT NULL UNIQUE,
  avatar_url text,
  description text,
  zipcode text,
  CONSTRAINT clubs_pkey PRIMARY KEY (id),
  CONSTRAINT clubs_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);

-- Migration to add zipcode column to existing clubs table:
-- ALTER TABLE public.clubs ADD COLUMN zipcode text;
CREATE TABLE public.event_rsvps (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  event_id uuid NOT NULL,
  declared_weight integer,
  status text NOT NULL CHECK (status = ANY (ARRAY['going'::text, 'maybe'::text, 'out'::text])),
  user_id uuid NOT NULL,
  CONSTRAINT event_rsvps_pkey PRIMARY KEY (id),
  CONSTRAINT event_rsvps_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.club_events(id),
  CONSTRAINT event_rsvps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.global_leaderboard_entries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  total_distance numeric DEFAULT 0,
  total_elevation numeric DEFAULT 0,
  total_tonnage numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  week_start date NOT NULL,
  user_id uuid NOT NULL,
  CONSTRAINT global_leaderboard_entries_pkey PRIMARY KEY (id),
  CONSTRAINT global_leaderboard_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.leaderboard_entries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  total_distance numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  total_weight_carried numeric DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  total_elevation numeric DEFAULT 0,
  club_id uuid,
  week_start date NOT NULL,
  user_id uuid,
  CONSTRAINT leaderboard_entries_pkey PRIMARY KEY (id),
  CONSTRAINT leaderboard_entries_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT leaderboard_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.post_likes (
  created_at timestamp with time zone DEFAULT now(),
  user_id uuid NOT NULL,
  post_id uuid NOT NULL,
  CONSTRAINT post_likes_pkey PRIMARY KEY (post_id, user_id),
  CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.club_posts(id),
  CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  longest_streak integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  total_distance numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  current_streak integer DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  bio text,
  username text NOT NULL UNIQUE,
  avatar_url text,
  id uuid NOT NULL,
  display_name text NOT NULL,
  location text,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_subscriptions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  started_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  user_id uuid NOT NULL,
  subscription_type text NOT NULL CHECK (subscription_type = ANY (ARRAY['monthly'::text, 'yearly'::text, 'ambassador'::text])),
  apple_transaction_id text,
  status text NOT NULL CHECK (status = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text])),
  expires_at timestamp with time zone,
  CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);