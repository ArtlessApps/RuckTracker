-- Add optional description to club_events (for create/edit event flow)
ALTER TABLE public.club_events
ADD COLUMN IF NOT EXISTS description text;
