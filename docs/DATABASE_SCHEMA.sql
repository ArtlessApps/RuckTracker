-- RuckTracker (MARCH) Community Database Schema
-- Supabase PostgreSQL
-- Last updated: January 2026
--
-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

-- =============================================
-- PROFILES
-- User profiles linked to Supabase auth.users
-- =============================================
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text NOT NULL UNIQUE,
  display_name text NOT NULL,
  avatar_url text,
  bio text,
  location text,
  total_distance numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  current_streak integer DEFAULT 0,
  longest_streak integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

-- =============================================
-- CLUBS
-- Community groups that users can join
-- =============================================
CREATE TABLE public.clubs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  join_code text NOT NULL UNIQUE,        -- e.g., "SAN-8154"
  created_by uuid,
  is_private boolean DEFAULT false,
  avatar_url text,
  member_count integer DEFAULT 1,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT clubs_pkey PRIMARY KEY (id),
  CONSTRAINT clubs_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);

-- =============================================
-- CLUB_MEMBERS
-- Junction table for club membership
-- Composite primary key prevents duplicate memberships
-- =============================================
CREATE TABLE public.club_members (
  club_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text DEFAULT 'member'::text CHECK (role = ANY (ARRAY['admin'::text, 'moderator'::text, 'member'::text])),
  joined_at timestamp with time zone DEFAULT now(),
  CONSTRAINT club_members_pkey PRIMARY KEY (club_id, user_id),
  CONSTRAINT club_members_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);

-- =============================================
-- CLUB_POSTS
-- Activity feed posts within clubs
-- =============================================
CREATE TABLE public.club_posts (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  club_id uuid,
  user_id uuid,
  post_type text DEFAULT 'workout'::text CHECK (post_type = ANY (ARRAY['workout'::text, 'text'::text, 'question'::text])),
  content text,
  workout_id uuid,                        -- Reference to local workout (if post_type = 'workout')
  distance_miles double precision,
  duration_minutes integer,
  weight_lbs double precision,
  calories integer,
  like_count integer DEFAULT 0,
  comment_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT club_posts_pkey PRIMARY KEY (id),
  CONSTRAINT club_posts_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT club_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);

-- =============================================
-- POST_LIKES
-- Tracks which users liked which posts
-- Composite primary key prevents duplicate likes
-- =============================================
CREATE TABLE public.post_likes (
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT post_likes_pkey PRIMARY KEY (post_id, user_id),
  CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.club_posts(id),
  CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);

-- =============================================
-- LEADERBOARD_ENTRIES
-- Weekly leaderboard rankings per club
-- =============================================
CREATE TABLE public.leaderboard_entries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  club_id uuid,
  user_id uuid,
  week_start date NOT NULL,               -- Monday of the week
  total_distance numeric DEFAULT 0,
  total_workouts integer DEFAULT 0,
  total_weight_carried numeric DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT leaderboard_entries_pkey PRIMARY KEY (id),
  CONSTRAINT leaderboard_entries_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id),
  CONSTRAINT leaderboard_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);

-- =============================================
-- RECOMMENDED RLS POLICIES
-- =============================================

-- PROFILES: Users can read all profiles, update only their own
-- CLUBS: Members can read their clubs, admins can update
-- CLUB_MEMBERS: Members can read membership, users can join/leave
-- CLUB_POSTS: Members can read/create posts in their clubs
-- POST_LIKES: Members can like/unlike posts in their clubs
-- LEADERBOARD_ENTRIES: Members can read leaderboards for their clubs
