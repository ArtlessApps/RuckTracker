# MARCH v2.0 - Complete Feature Testing Guide

A comprehensive guide for testing all club, leaderboard, and badge features in MARCH.

---

## Table of Contents

1. [Setup & Test Accounts](#setup--test-accounts)
2. [Club Role Testing](#club-role-testing)
3. [Global Leaderboard Testing](#global-leaderboard-testing)
4. [Badges & Trophy Case Testing](#badges--trophy-case-testing)
5. [Event & RSVP Testing](#event--rsvp-testing)
6. [Free vs PRO Feature Testing](#free-vs-pro-feature-testing)
7. [Ambassador Program Testing](#ambassador-program-testing)
8. [Club Discovery Testing](#club-discovery-testing)
9. [Quick Reference Tables](#quick-reference-tables)
10. [SQL Debugging Queries](#sql-debugging-queries)

---

## Setup & Test Accounts

### Create These Test Accounts

| Account | Email | Username | Role | Subscription |
|---------|-------|----------|------|--------------|
| **Founder** | founder@test.com | founder_nick | Creates "Test Ruck Club" | Free |
| **Leader** | leader@test.com | leader_sarah | Gets promoted to Leader | Free |
| **Member** | member@test.com | member_jake | Basic member | Free |
| **Pro User** | pro@test.com | pro_maria | Has active subscription | PRO |
| **Outsider** | outsider@test.com | outsider_tom | Not in any club | Free |

### Test Data Seeding (Recommended)

If you run `TEST_DATA_SEED.sql` in Supabase, it creates pre-configured test accounts with the usernames shown above.

> **Note**: The app only uses `username` for display. If you see a different name, the test data may need to be re-seeded.

### Database Trigger Setup

Before testing signups, ensure the profile creation trigger is set up. Run `REMOVE_DISPLAY_NAME_MIGRATION.sql` in Supabase SQL Editor. This trigger:
- Auto-creates profiles when users sign up
- Uses the username from signup metadata
- Handles duplicate usernames with fallback logic

### Initial Setup Steps

1. Run `REMOVE_DISPLAY_NAME_MIGRATION.sql` in Supabase (one-time setup)
2. Run `TEST_DATA_SEED.sql` OR create accounts manually
3. As **founder@test.com**: Create "Test Ruck Club"
4. As **leader@test.com**: Join the club, then get promoted by founder
5. As **member@test.com**: Join the club via invite code
6. As **pro@test.com**: Purchase subscription, then join the club

---

## Club Role Testing

### Scenario 1: Member Experience

> Sign in as **member@test.com**

#### Joining a Club

1. Go to Community → Join Club
2. Enter the invite code
3. **Waiver flow should appear** with 3 steps:
   - Step 1: Read safety briefing (must scroll to continue)
   - Step 2: Enter emergency contact name + phone
   - Step 3: Tap to sign digitally
4. After signing, you're in the club

#### What Members CAN Do

- View the Events, Feed, and Leaderboard tabs
- RSVP to events (Going / Maybe / Out)
- Enter ruck weight when RSVPing "Going"
- Post comments in The Wire
- Complete workouts that auto-post to club feed
- View club leaderboard
- Like posts in the feed
- View their own badges in Trophy Case

#### What Members CANNOT Do

- See the club invite code
- Create or edit events
- Manage other members (promote/demote/remove)
- View emergency contacts
- Delete the club

#### Member Test Checklist

```
[ ] Waiver flow completes successfully with all 3 steps
[ ] Can view all tabs (Events, Feed, Leaderboard)
[ ] Can RSVP to an event with weight declaration
[ ] Can post a comment in The Wire
[ ] Can like posts in the feed
[ ] Cannot see "Create Event" button
[ ] Cannot see invite code in Members view
[ ] Cannot see member management options (promote/demote/remove)
```

---

### Scenario 2: Leader Experience

> Sign in as **leader@test.com**

#### Getting Promoted

1. Ask Founder to promote you (or promote yourself as Founder first)
2. Refresh the club view
3. You should now have Leader capabilities

#### What Leaders CAN Do

Everything Members can do, plus:
- See and share the club invite code
- Create new events
- Edit/delete events they created

#### What Leaders CANNOT Do

- Promote or demote other members
- Remove members from the club
- View emergency contacts
- Delete the club
- Transfer ownership

#### Leader Test Checklist

```
[ ] Can see invite code at top of Members view
[ ] Can copy/share invite code
[ ] "Create Event" button appears in Events tab
[ ] Can create an event with:
    [ ] Title (required)
    [ ] Date/time (required)
    [ ] Address/location
    [ ] Meeting point description
[ ] Can edit an event after creating it
[ ] Can delete an event they created
[ ] Can tap into other members and see member details
[ ] Can see "View Emergency Contact" option (for members who signed waiver)
[ ] Can see "Remove from Club" option
[ ] Cannot see "Promote to Leader" option on any member
```

---

### Scenario 3: Founder Experience

> Sign in as **founder@test.com**

**Important:** Founder permissions are **per club**. You should only see founder capabilities (Settings, Promote/Demote, Transfer Ownership, Delete Club, etc.) in clubs where you are the founder. In any other club, you are a **member** by default (or leader only if promoted there); you must see only that role’s capabilities.

#### Full Control Capabilities

Founders have complete control over the club:

| Capability | Description |
|------------|-------------|
| View/Share Invite Code | See and regenerate the club invite code |
| Create Events | Create, edit, delete any event |
| Promote to Leader | Upgrade members to leader role |
| Demote to Member | Downgrade leaders to member role |
| Remove Members | Kick anyone from the club |
| View Emergency Contacts | Access waiver info for members |
| Edit Club Details | Change name, description, privacy |
| Regenerate Invite Code | Get a new invite code |
| Transfer Ownership | Make another member the founder |
| Delete Club | Permanently delete the club |

#### Member Management Test

1. Go to Members tab
2. Tap on a regular member:
   - You should see: **Promote to Leader**, **View Emergency Contact**, **Remove from Club**
3. Tap on a leader:
   - You should see: **Demote to Member**, **View Emergency Contact**, **Remove from Club**
4. Tap on yourself:
   - You should see: **Transfer Ownership**, **Leave Club** (with warning)

#### Founder Test Checklist

```
[ ] Can see and copy invite code
[ ] Can regenerate invite code
[ ] Can promote member@test.com to Leader
[ ] Can demote them back to Member
[ ] Can view emergency contact info (has name + phone)
[ ] Emergency contact has "Call Now" button that opens dialer
[ ] Can remove a member (test with a throwaway account)
[ ] Warning appears if trying to leave as Founder
[ ] Can edit club name and description
[ ] Can toggle club privacy (public/private)
[ ] Can transfer ownership to another member
[ ] In a club where founder@test.com is NOT the founder: they are a member by default (or leader only if promoted). No Settings, no Promote/Demote, no Transfer/Delete; only that role’s capabilities for that club
```

---

## Global Leaderboard Testing

> PRO feature - requires subscription to view rankings

### Accessing Global Leaderboards

1. Navigate to the Rankings tab
2. If not PRO: Should see blur overlay with lock icon and upgrade CTA
3. If PRO: Should see full leaderboard with rankings

### Four Leaderboard Types

| Type | View Name | Period | Unit | Icon |
|------|-----------|--------|------|------|
| **Road Warriors** | Distance | This Week | mi | figure.walk |
| **Heavy Haulers** | Tonnage | All Time | lbs-mi | scalemass.fill |
| **Vertical Gainers** | Elevation | This Month | ft | arrow.up.right |
| **Iron Discipline** | Consistency | Last 30 Days | days | calendar.badge.checkmark |

### Prerequisite: Seed Global Leaderboard Data

Before testing leaderboards you must have data in `global_leaderboard_entries` for
the **current** week. Run the SQL in `docs/GLOBAL_LEADERBOARD_VIEWS.sql` to create
the views and update function, then seed test data:

```sql
-- Get test user IDs
SELECT id, username FROM profiles ORDER BY created_at LIMIT 10;

-- Insert seed entries for the current week (replace UUIDs)
INSERT INTO global_leaderboard_entries
  (user_id, week_start, total_distance, total_elevation, total_tonnage, total_workouts)
VALUES
  ('<pro_user_uuid>',    date_trunc('week', CURRENT_DATE)::date, 12.5, 850,  312.5, 3),
  ('<member_user_uuid>', date_trunc('week', CURRENT_DATE)::date, 8.3,  420,  207.5, 2),
  ('<other_user_uuid>',  date_trunc('week', CURRENT_DATE)::date, 15.1, 1200, 453.0, 4)
ON CONFLICT (user_id, week_start) DO UPDATE SET
  total_distance  = EXCLUDED.total_distance,
  total_elevation = EXCLUDED.total_elevation,
  total_tonnage   = EXCLUDED.total_tonnage,
  total_workouts  = EXCLUDED.total_workouts,
  updated_at      = now();
```

> **Note**: Distance (weekly) and Elevation (monthly) leaderboards are time-sensitive.
> If entries have a `week_start` outside the current week/month, those capsules will be empty.
> The seed data above uses `date_trunc('week', CURRENT_DATE)` to always match the current period.

### Testing Leaderboard Display

> Sign in as **pro@test.com**

1. Navigate to Rankings tab
2. Verify type selector (horizontal scrollable capsules)
3. Switch between all 4 leaderboard types
4. For each type, verify:
   - Period description displays correctly
   - Unit label is correct
   - Entries show: Rank, Avatar, Username, Score
   - PRO users show crown badge next to username
   - Current user is highlighted with "That's you!" label

### PRO Gate Testing

> Sign in as **member@test.com** (free user)

1. Navigate to Rankings tab
2. Should see blur overlay over the leaderboard
3. Should see lock icon and "Global Rankings" title
4. Should see "Unlock Global Rankings" button
5. Tapping button should present subscription paywall

### Leaderboard Test Checklist

```
[ ] PREREQUISITE: global_leaderboard_entries seeded for current week (see above)
[ ] PREREQUISITE: 4 views created in Supabase (see GLOBAL_LEADERBOARD_VIEWS.sql)
[ ] FREE USER: Blur overlay appears on Rankings tab
[ ] FREE USER: Lock icon and CTA button visible
[ ] FREE USER: "PRO FEATURE" badge shows
[ ] FREE USER: Tapping unlock button shows paywall
[ ] PRO USER: Full leaderboard visible without blur
[ ] PRO USER: Can switch between all 4 types
[ ] Distance leaderboard shows entries AND "This Week" period
[ ] Tonnage leaderboard shows entries AND "All Time" period
[ ] Elevation leaderboard shows entries AND "This Month" period
[ ] Consistency leaderboard shows entries AND "Last 30 Days" period
[ ] Top 3 ranks show trophy/medal icons (gold, silver, bronze)
[ ] Ranks 4+ show numeric rank
[ ] PRO users show yellow crown next to username
[ ] Current user's row is highlighted
[ ] Scores format correctly (distance: 1 decimal, elevation: whole number, consistency: integer)
```

---

## Badges & Trophy Case Testing

### Badge Categories

| Category | Badges | Tier Colors |
|----------|--------|-------------|
| **PRO** | PRO Athlete | Gold/Yellow |
| **Distance** | 100 Mile Club, 500 Mile Club, 1000 Mile Club | Bronze → Silver → Gold |
| **Tonnage** | Heavy Hauler, Freight Train, Iron Giant | Bronze → Silver → Gold |
| **Elevation** | The Sherpa, Everester | Silver, Gold |
| **Programs** | Light Ready, Heavy Ready, Selection Ready | Silver → Gold → Platinum |
| **Streaks** | Week Warrior, Month Master, Iron Discipline | Bronze → Silver → Gold |
| **Community** | Club Founder, Community Leader | Silver, Gold |

### Trophy Case Display

1. Go to Profile → Trophy Case
2. Verify compact view shows up to 6 badges
3. Earned badges display in full color with tier gradient
4. Locked badges display in grayscale with lock overlay
5. Badge count shows "X earned" label
6. Tap "Trophy Case" header to see full sheet

### Full Trophy Case Sheet

1. Shows stats header: Earned / Locked / Complete %
2. Shows all badges in 3-column grid
3. Earned badges are full color
4. Locked badges are grayed with lock icon
5. Tapping any badge shows detail view

### Badge Detail View

1. Shows large badge icon (colored if earned, gray if locked)
2. Shows badge name and tier label
3. Shows description of how to earn
4. If earned: Green "Earned" status
5. If locked: "Not Yet Earned" with encouragement text

### Badge Test Checklist

```
[ ] Trophy Case appears in Profile view
[ ] Compact view shows up to 6 badges
[ ] Badge count shows "X earned"
[ ] Earned badges show full color gradient
[ ] Locked badges show grayscale with lock overlay
[ ] Tapping header opens full trophy case sheet
[ ] Full sheet shows Earned/Locked/Complete stats
[ ] All 17 badges appear in grid
[ ] Tapping badge opens detail view
[ ] PRO badge shows if user has subscription
[ ] Badge details show correct tier (Bronze/Silver/Gold/Platinum/PRO)
[ ] Locked badges show "Not Yet Earned" status
[ ] Earned badges show green "Earned" status
```

### Badge Awarding (Backend)

To award a test badge manually:

```sql
INSERT INTO user_badges (user_id, badge_id)
VALUES ('USER_UUID', '100_mile_club');
```

Available badge IDs:
- `pro_athlete`, `100_mile_club`, `500_mile_club`, `1000_mile_club`
- `heavy_hauler`, `freight_train`, `iron_giant`
- `the_sherpa`, `everester`
- `selection_ready`, `heavy_ready`, `light_ready`
- `week_warrior`, `month_master`, `iron_discipline`
- `club_founder`, `community_leader`

---

## Event & RSVP Testing

### Creating an Event (Leader/Founder)

> Sign in as **leader@test.com** or **founder@test.com**

1. Go to Events tab
2. Tap "Create Event"
3. Fill in all fields:

| Field | Required | Description |
|-------|----------|-------------|
| Title | Yes | Event name |
| Date/Time | Yes | When event starts |
| Address | No | Location address |
| Meeting Point | No | Specific instructions ("Park behind Wendy's") |

4. Tap Create

### RSVP Flow (Any Member)

1. Tap on an event in the list
2. View event details (map, time, requirements)
3. Tap RSVP button
4. Select status: **Going** / **Maybe** / **Out**
5. If Going: Enter your ruck weight declaration
6. Confirm RSVP

### The Wire (Event Comments)

1. Scroll to comments section on event detail
2. Enter a message
3. Tap send
4. Comment appears with username and timestamp

### Attendee List

1. View event detail
2. Scroll to "Who's Coming" section
3. Should show:
   - List of "Going" attendees with declared weights
   - List of "Maybe" attendees
   - Total group tonnage calculation

### Event Notifications

1. RSVP "Going" to a future event
2. A notification should be scheduled for 1 hour before
3. Change RSVP to "Out" - notification should cancel
4. Change back to "Going" - notification re-schedules

### Event Test Checklist

```
[ ] Leader/Founder can create event with all fields
[ ] Event appears in Events tab list/calendar
[ ] Event shows location on map
[ ] RSVP buttons work (Going/Maybe/Out)
[ ] Weight declaration appears when selecting "Going"
[ ] Attendee list shows RSVPs with declared weights
[ ] Group tonnage calculates: Σ(declared weights)
[ ] Wire comments work - can post and see messages
[ ] 1-hour reminder notification is scheduled
[ ] Changing to "Out" cancels notification
[ ] Leader can edit their own events
[ ] Founder can edit/delete any event
[ ] Members cannot create/edit events
```

---

## Free vs PRO Feature Testing

### Feature Matrix

| Feature | Free | PRO |
|---------|------|-----|
| Basic workout tracking | ✓ | ✓ |
| Open Ruck mode | ✓ | ✓ |
| Club membership | ✓ | ✓ |
| Club feed & leaderboards | ✓ | ✓ |
| RSVP to events | ✓ | ✓ |
| View training plan | ✓ | ✓ |
| Start plan workout | Paywall | ✓ |
| Audio coaching | ✗ | ✓ |
| Heart rate zones | ✗ | ✓ |
| Interval timers | ✗ | ✓ |
| **Global Leaderboards** | Locked | ✓ |
| Tonnage share metric | Locked | ✓ |
| Club badge on share card | Locked | ✓ |

### Free User Testing

> Sign in as **member@test.com**

```
[ ] Can view training plan
[ ] Paywall appears when tapping "Start Workout" from plan
[ ] Paywall shows monthly ($4.99) and yearly ($39.99) options
[ ] "Use Free Version" button dismisses paywall
[ ] Can complete Open Ruck without restrictions
[ ] Share card works but Propaganda Mode options are locked
[ ] Global Rankings tab shows blur overlay with upgrade CTA
```

### PRO User Testing

> Sign in as **pro@test.com**

```
[ ] PRO badge appears in profile/settings
[ ] Can start workout from training plan directly
[ ] Audio coaching plays during workout
[ ] Propaganda Mode toggles work (tonnage + club badge)
[ ] Share card shows tonnage calculation (weight × distance)
[ ] Share card shows "TRAINING WITH [CLUB NAME]"
[ ] Global Rankings fully visible without blur
[ ] PRO crown appears next to username on leaderboards
[ ] PRO Athlete badge appears in Trophy Case
```

---

## Ambassador Program Testing

### Qualification Criteria

You become an **Ambassador** when:
1. You are the **Founder** of a club
2. That club has **5 or more members** (including you)

### Testing the Ambassador Flow

1. Create a new club (or use existing)
2. Note current premium status (should be Free)
3. Have 4 other accounts join the club
4. Check premium status again
5. Should now have **Ambassador** status with free PRO access

### Ambassador Status Indicators

| State | Expected Behavior |
|-------|-------------------|
| < 5 members | Free user, no special status |
| ≥ 5 members | AMBASSADOR badge (not PRO badge) |
| Members leave (< 5) | Status revoked |
| Members rejoin (≥ 5) | Status restored |

### Ambassador Test Checklist

```
[ ] With 4 members (below threshold): No Ambassador status
[ ] With 5 members: Ambassador status activates
[ ] AMBASSADOR badge appears (not PRO badge)
[ ] PRO features work without subscription
[ ] Global leaderboards unlocked
[ ] If members leave and drop below 5: Status revoked
[ ] If members rejoin back to 5: Status restored immediately
[ ] Ambassador gets PRO features but PRO Athlete badge doesn't appear
```

### Force Refresh Ambassador Status (iOS)

```swift
await PremiumManager.shared.checkAmbassadorStatus()
```

---

## Club Discovery Testing

### Find Nearby Clubs

1. Go to Community → Find Clubs
2. Enter a ZIP code
3. System should:
   - Geocode ZIP to coordinates
   - Search for public clubs within 50 miles
   - Also show "global" clubs (no location set)

### Discovery Results

| Club Type | Description |
|-----------|-------------|
| **Nearby** | Public clubs with coordinates within radius |
| **Global** | Public clubs with no location (appear in all searches) |
| **Private** | Never appear in discovery (invite-only) |

### Joining from Discovery

1. Find a club in discovery results
2. Tap "Join" button
3. Should trigger waiver flow
4. After signing, you're a member

### Club Discovery Test Checklist

```
[ ] Can enter ZIP code to search
[ ] Nearby clubs appear sorted by distance
[ ] Distance shown for each club (e.g., "2.3 mi away")
[ ] Global clubs appear after nearby clubs
[ ] Private clubs do NOT appear in search
[ ] Tapping Join triggers waiver flow
[ ] After waiver, club appears in My Clubs
[ ] Can search without ZIP (shows all public clubs)
[ ] Club member count displays correctly
```

---

## Quick Reference Tables

### Role Permissions Matrix

| Action | Member | Leader | Founder |
|--------|--------|--------|---------|
| View events | ✓ | ✓ | ✓ |
| RSVP to events | ✓ | ✓ | ✓ |
| Post to Wire | ✓ | ✓ | ✓ |
| View club feed | ✓ | ✓ | ✓ |
| Like posts | ✓ | ✓ | ✓ |
| See invite code | | ✓ | ✓ |
| Create events | | ✓ | ✓ |
| Edit own events | | ✓ | ✓ |
| Edit any event | | | ✓ |
| Delete any event | | | ✓ |
| Promote to Leader | | | ✓ |
| Demote to Member | | | ✓ |
| Remove members | | | ✓ |
| View emergency contacts | | | ✓ |
| Edit club details | | | ✓ |
| Regenerate invite code | | | ✓ |
| Transfer ownership | | | ✓ |
| Delete club | | | ✓ |

### Global Leaderboard Views

| Display Name | Table Name | Metric | Reset Period |
|--------------|------------|--------|--------------|
| Road Warriors | global_leaderboard_distance_weekly | Sum of miles | Every Monday |
| Heavy Haulers | global_leaderboard_tonnage_alltime | Sum of lbs-mi | Never (all-time) |
| Vertical Gainers | global_leaderboard_elevation_monthly | Sum of ft gained | 1st of month |
| Iron Discipline | global_leaderboard_consistency | Distinct workout days | Rolling 30 days |

### Badge Tiers & Colors

| Tier | Color | Accent | Use Case |
|------|-------|--------|----------|
| Bronze | #CC8033 | #994A26 | Entry-level achievements |
| Silver | #BFBFCC | #8C8C99 | Mid-tier milestones |
| Gold | #FFD700 | #D9A600 | Major achievements |
| Platinum | #E6E6FA | #B3B3D9 | Elite status |
| PRO | Gold | Orange | Subscription status |

---

## SQL Debugging Queries

### Check a User's Role

```sql
SELECT p.username, cm.role, c.name 
FROM club_members cm
JOIN profiles p ON p.id = cm.user_id
JOIN clubs c ON c.id = cm.club_id
WHERE p.username = 'testuser';
```

### Check Ambassador Eligibility

```sql
SELECT c.name, c.member_count
FROM clubs c
JOIN club_members cm ON cm.club_id = c.id
WHERE cm.user_id = 'your-uuid' 
  AND cm.role = 'founder'
  AND c.member_count >= 5;
```

### View User's Badges

```sql
SELECT ub.badge_id, ub.awarded_at
FROM user_badges ub
WHERE ub.user_id = 'your-uuid'
ORDER BY ub.awarded_at DESC;
```

### Award a Badge Manually

```sql
INSERT INTO user_badges (user_id, badge_id)
VALUES ('user-uuid', 'badge-id')
ON CONFLICT (user_id, badge_id) DO NOTHING;
```

### Check Leaderboard Rankings

```sql
-- Weekly Distance
SELECT * FROM global_leaderboard_distance_weekly LIMIT 10;

-- All-Time Tonnage  
SELECT * FROM global_leaderboard_tonnage_alltime LIMIT 10;

-- Monthly Elevation
SELECT * FROM global_leaderboard_elevation_monthly LIMIT 10;

-- Consistency (30 days)
SELECT * FROM global_leaderboard_consistency LIMIT 10;
```

### Check PRO Status in Profiles

```sql
SELECT id, username, is_premium
FROM profiles
WHERE username = 'testuser';
```

### Update PRO Status Manually

```sql
UPDATE profiles
SET is_premium = true
WHERE username = 'testuser';
```

### Find Nearby Clubs (Raw Query)

```sql
SELECT * FROM find_nearby_clubs(
    user_lat := 32.7157,  -- San Diego latitude
    user_lon := -117.1611, -- San Diego longitude
    radius_miles := 50
);
```

### Check Event RSVPs with Tonnage

```sql
SELECT 
    e.title,
    COUNT(*) FILTER (WHERE er.status = 'going') AS going_count,
    SUM(er.declared_weight) FILTER (WHERE er.status = 'going') AS total_tonnage
FROM club_events e
LEFT JOIN event_rsvps er ON er.event_id = e.id
WHERE e.club_id = 'club-uuid'
GROUP BY e.id, e.title;
```

---

## iOS Debug Commands

### Force Refresh Premium Status

```swift
await PremiumManager.shared.checkAmbassadorStatus()
```

### Clear Local Session

```swift
await CommunityService.shared.signOut()
```

### Reload Current Profile

```swift
try await CommunityService.shared.loadCurrentProfile()
```

### Reload Clubs

```swift
try await CommunityService.shared.loadMyClubs()
```

### Force Fetch Global Leaderboard

```swift
let entries = try await CommunityService.shared.fetchGlobalLeaderboard(type: .distance)
```

---

## Testing Workflow Summary

### Quick Smoke Test (5 minutes)

1. Sign in as free user → verify leaderboard is locked
2. Sign in as PRO user → verify leaderboard visible
3. Check Trophy Case → verify badges display
4. Join a club → verify waiver flow
5. Create an event → verify RSVP works

### Full Regression Test (30 minutes)

1. Complete all Member scenarios
2. Complete all Leader scenarios  
3. Complete all Founder scenarios
4. Test Free vs PRO feature gates
5. Test all 4 leaderboard types
6. Test badge display and details
7. Test event creation and RSVP flow
8. Test club discovery
9. Test Ambassador flow (if possible)

---

*Last updated: January 2026*
