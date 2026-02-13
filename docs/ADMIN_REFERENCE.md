# MARCH - Admin Reference

Quick reference for managing the MARCH app backend via Supabase.

---

## Table of Contents

1. [Database Setup](#database-setup)
2. [Badge Management](#badge-management)
3. [User & Role Queries](#user--role-queries)
4. [Leaderboard Queries](#leaderboard-queries)
5. [PRO Subscription Management](#pro-subscription-management)
6. [Club & Event Queries](#club--event-queries)
7. [iOS Debug Commands](#ios-debug-commands)

---

## Database Setup

### Profile Creation Trigger

Before accepting signups, ensure the profile creation trigger is set up. Run `REMOVE_DISPLAY_NAME_MIGRATION.sql` in the Supabase SQL Editor. This trigger:
- Auto-creates profiles when users sign up
- Uses the username from signup metadata
- Handles duplicate usernames with fallback logic

### Test Data Seeding

Run `TEST_DATA_SEED.sql` in Supabase to create pre-configured test accounts.

> **Note**: The app only uses `username` for display. If you see a different name, the test data may need to be re-seeded.

---

## Badge Management

### Available Badge IDs

| Category | Badge IDs |
|----------|-----------|
| **PRO** | `pro_athlete` |
| **Distance** | `100_mile_club`, `500_mile_club`, `1000_mile_club` |
| **Tonnage** | `heavy_hauler`, `freight_train`, `iron_giant` |
| **Elevation** | `the_sherpa`, `everester` |
| **Programs** | `selection_ready`, `heavy_ready`, `light_ready` |
| **Streaks** | `week_warrior`, `month_master`, `iron_discipline` |
| **Community** | `club_founder`, `community_leader` |

### Award a Badge

```sql
INSERT INTO user_badges (user_id, badge_id)
VALUES ('user-uuid', 'badge-id')
ON CONFLICT (user_id, badge_id) DO NOTHING;
```

### View a User's Badges

```sql
SELECT ub.badge_id, ub.awarded_at
FROM user_badges ub
WHERE ub.user_id = 'your-uuid'
ORDER BY ub.awarded_at DESC;
```

### Revoke a Badge

```sql
DELETE FROM user_badges
WHERE user_id = 'user-uuid'
  AND badge_id = 'badge-id';
```

---

## User & Role Queries

### Check a User's Club Role

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

---

## Leaderboard Queries

### View Leaderboard Rankings

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

### Seed Leaderboard Data for Current Week

```sql
-- Get user IDs
SELECT id, username FROM profiles ORDER BY created_at LIMIT 10;

-- Insert seed entries (replace UUIDs with real values)
INSERT INTO global_leaderboard_entries
  (user_id, week_start, total_distance, total_elevation, total_tonnage, total_workouts)
VALUES
  ('<user_uuid_1>', date_trunc('week', CURRENT_DATE)::date, 12.5, 850,  312.5, 3),
  ('<user_uuid_2>', date_trunc('week', CURRENT_DATE)::date, 8.3,  420,  207.5, 2),
  ('<user_uuid_3>', date_trunc('week', CURRENT_DATE)::date, 15.1, 1200, 453.0, 4)
ON CONFLICT (user_id, week_start) DO UPDATE SET
  total_distance  = EXCLUDED.total_distance,
  total_elevation = EXCLUDED.total_elevation,
  total_tonnage   = EXCLUDED.total_tonnage,
  total_workouts  = EXCLUDED.total_workouts;
```

---

## PRO Subscription Management

### Check PRO Status

```sql
SELECT id, username, is_premium
FROM profiles
WHERE username = 'testuser';
```

### Grant PRO Status Manually

```sql
UPDATE profiles
SET is_premium = true
WHERE username = 'testuser';
```

### Revoke PRO Status

```sql
UPDATE profiles
SET is_premium = false
WHERE username = 'testuser';
```

---

## Club & Event Queries

### Find Nearby Clubs

```sql
SELECT * FROM find_nearby_clubs(
    user_lat := 32.7157,   -- San Diego latitude
    user_lon := -117.1611,  -- San Diego longitude
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

Use these in Xcode or during development to force-refresh app state.

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

## Quick Reference Tables

### Role Permissions Matrix

| Action | Member | Leader | Founder |
|--------|:------:|:------:|:-------:|
| View events | ✓ | ✓ | ✓ |
| RSVP to events | ✓ | ✓ | ✓ |
| Post to Wire | ✓ | ✓ | ✓ |
| View club feed | ✓ | ✓ | ✓ |
| Like posts | ✓ | ✓ | ✓ |
| See invite code | | ✓ | ✓ |
| Create events | | ✓ | ✓ |
| Edit/delete events | | ✓ | ✓ |
| View emergency contacts | | ✓ | ✓ |
| Remove members | | ✓ | ✓ |
| Promote to Leader | | | ✓ |
| Demote to Member | | | ✓ |
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
| Bronze | #CC8033 | #995926 | Entry-level achievements |
| Silver | #BFBFCC | #8C8C99 | Mid-tier milestones |
| Gold | #FFD600 | #D9A600 | Major achievements |
| Platinum | #E6E6FA | #B3B3D9 | Elite status |
| PRO | #FFD600 (Gold) | Orange | Subscription status |

---

*Last updated: February 2026*
