-- Final migration to complete schema alignment
-- Add the last missing field

-- Add created_at to user_challenge_enrollments if it doesn't exist
-- (Check if it exists first to avoid errors)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_challenge_enrollments' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.user_challenge_enrollments 
        ADD COLUMN created_at timestamp with time zone DEFAULT now();
    END IF;
END $$;
