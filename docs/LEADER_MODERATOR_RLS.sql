-- LEADER MODERATOR PERMISSIONS (RLS)
-- ----------------------------------
-- Use this only if you have Row Level Security (RLS) on public.club_members.
-- If RLS is not enabled, no database changes are required; the app enforces
-- permissions in Swift.
--
-- No table or column changes are needed; the role column already supports
-- 'founder', 'leader', and 'member'.

-- Allow founders to update member roles (promote to leader / demote to member).
-- Without this, UPDATEs to club_members.role are blocked and promote/demote appear to do nothing.
DROP POLICY IF EXISTS "Founder can update member roles" ON public.club_members;

CREATE POLICY "Founder can update member roles"
ON public.club_members
FOR UPDATE
USING (
  club_id IN (
    SELECT cm.club_id
    FROM public.club_members cm
    WHERE cm.user_id = auth.uid()
      AND cm.club_id = club_members.club_id
      AND cm.role = 'founder'
  )
);

-- Allow leaders (and founders) to remove non-founder members from the club.
-- Adjust the policy name if you already have a delete policy on club_members.
DROP POLICY IF EXISTS "Founder or leader can remove non-founder members" ON public.club_members;

CREATE POLICY "Founder or leader can remove non-founder members"
ON public.club_members
FOR DELETE
USING (
  club_id IN (
    SELECT cm.club_id
    FROM public.club_members cm
    WHERE cm.user_id = auth.uid()
      AND cm.club_id = club_members.club_id
      AND cm.role IN ('founder', 'leader')
  )
  AND user_id != auth.uid()
  AND role != 'founder'
);

-- Allow founders to update their own club (edit name/description, transfer ownership, etc.).
-- Without this, any UPDATE to the clubs table is blocked by RLS.
DROP POLICY IF EXISTS "Founder can update own club" ON public.clubs;

CREATE POLICY "Founder can update own club"
ON public.clubs
FOR UPDATE
USING (
  id IN (
    SELECT cm.club_id
    FROM public.club_members cm
    WHERE cm.user_id = auth.uid()
      AND cm.club_id = clubs.id
      AND cm.role = 'founder'
  )
);

-- Emergency contact: leaders need to SELECT other members' emergency_contact_json.
-- If your existing SELECT policy already lets "any member of the club read club_members
-- for that club", leaders already have access. If you have a stricter policy that
-- limits who can read other rows (e.g. only founders), add a policy so that
-- users with role 'founder' or 'leader' in that club can SELECT rows in the same club.
