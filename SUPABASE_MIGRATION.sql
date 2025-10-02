-- RuckTracker Supabase Migration
-- Add missing tables and fields to match your code requirements

-- =============================================
-- ADD MISSING TABLES
-- =============================================

-- Add program_progress table (referenced in ProgramService.swift)
CREATE TABLE public.program_progress (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    program_id uuid NOT NULL,
    workout_date timestamp with time zone NOT NULL,
    week_number integer NOT NULL,
    workout_number integer NOT NULL,
    weight_lbs numeric NOT NULL,
    distance_miles numeric NOT NULL,
    duration_minutes integer NOT NULL,
    completed boolean DEFAULT false,
    notes text,
    heart_rate_data jsonb,
    pace_data jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT program_progress_pkey PRIMARY KEY (id),
    CONSTRAINT program_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT program_progress_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.programs(id) ON DELETE CASCADE
);

-- Add workout_sessions table (referenced in SupabaseConfig.swift)
CREATE TABLE public.workout_sessions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    workout_id uuid,
    session_start timestamp with time zone NOT NULL,
    session_end timestamp with time zone,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT workout_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT workout_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT workout_sessions_workout_id_fkey FOREIGN KEY (workout_id) REFERENCES public.workouts(id) ON DELETE CASCADE
);

-- =============================================
-- ADD MISSING FIELDS TO EXISTING TABLES
-- =============================================

-- Add missing fields to workouts table
ALTER TABLE public.workouts 
ADD COLUMN ruck_weight numeric;

-- Add missing fields to programs table
ALTER TABLE public.programs 
ADD COLUMN is_active boolean DEFAULT true,
ADD COLUMN sort_order integer DEFAULT 0;

-- Add missing fields to user_programs table
ALTER TABLE public.user_programs 
ADD COLUMN enrolled_at timestamp with time zone DEFAULT now(),
ADD COLUMN starting_weight_lbs numeric,
ADD COLUMN target_weight_lbs numeric,
ADD COLUMN completion_percentage numeric DEFAULT 0.0,
ADD COLUMN next_workout_date timestamp with time zone;

-- Add missing field to user_challenge_enrollments table
ALTER TABLE public.user_challenge_enrollments 
ADD COLUMN created_at timestamp with time zone DEFAULT now();

-- =============================================
-- UPDATE EXISTING DATA
-- =============================================

-- Update user_programs to set enrolled_at = started_at for existing records
UPDATE public.user_programs 
SET enrolled_at = started_at 
WHERE enrolled_at IS NULL AND started_at IS NOT NULL;

-- =============================================
-- ADD INDEXES FOR PERFORMANCE
-- =============================================

-- Program progress indexes
CREATE INDEX idx_program_progress_user_id ON public.program_progress(user_id);
CREATE INDEX idx_program_progress_program_id ON public.program_progress(program_id);
CREATE INDEX idx_program_progress_workout_date ON public.program_progress(workout_date);

-- Workout sessions indexes
CREATE INDEX idx_workout_sessions_user_id ON public.workout_sessions(user_id);
CREATE INDEX idx_workout_sessions_workout_id ON public.workout_sessions(workout_id);

-- =============================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================

-- Enable RLS on new tables
ALTER TABLE public.program_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;

-- =============================================
-- ADD RLS POLICIES
-- =============================================

-- Program progress policies
CREATE POLICY "Users can view their own program progress" ON public.program_progress
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own program progress" ON public.program_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own program progress" ON public.program_progress
    FOR UPDATE USING (auth.uid() = user_id);

-- Workout sessions policies
CREATE POLICY "Users can view their own workout sessions" ON public.workout_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workout sessions" ON public.workout_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workout sessions" ON public.workout_sessions
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================
-- ADD UPDATED_AT TRIGGERS
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers to new tables
CREATE TRIGGER update_program_progress_updated_at 
    BEFORE UPDATE ON public.program_progress 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_workout_sessions_updated_at 
    BEFORE UPDATE ON public.workout_sessions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
