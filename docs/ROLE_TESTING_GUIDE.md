# MARCH v2.0 Role Testing Guide

---

## Setup

Create 4 test accounts and one test club:

- **founder@test.com** → Creates "Test Ruck Club"
- **leader@test.com** → Joins club, gets promoted to Leader
- **member@test.com** → Joins club, stays as Member
- **pro@test.com** → Joins club, purchases Pro subscription

---

## Scenario 1: Member Experience

> Sign in as **member@test.com**

### Joining a Club

1. Go to Community → Join Club
2. Enter the join code
3. **Waiver sheet should appear** with 3 steps:
   - Step 1: Read safety briefing (must scroll)
   - Step 2: Enter emergency contact name + phone
   - Step 3: Tap to sign digitally
4. After signing, you're in the club

### What Members CAN Do

- View the Events, Feed, and Leaderboard tabs
- RSVP to events (Going / Maybe / Out)
- Enter ruck weight when RSVPing
- Post comments in The Wire
- Complete workouts that post to club feed
- View club leaderboard

### What Members CANNOT Do

- See the club join code
- Create or edit events
- Manage other members
- View emergency contacts

### Test Checklist

```
[ ] Waiver flow completes successfully
[ ] Can view all 3 tabs (Events, Feed, Leaderboard)
[ ] Can RSVP to an event with weight declaration
[ ] Can post a comment in The Wire
[ ] Cannot see "Create Event" button
[ ] Cannot see join code in Members view
```

---

## Scenario 2: Leader Experience

> Sign in as **leader@test.com**

### Getting Promoted

1. Ask Founder to promote you (or do it yourself as Founder first)
2. Refresh the club view
3. You should now have Leader capabilities

### What Leaders CAN Do

Everything Members can do, plus:
- See the club join code
- Create new events
- Edit/delete events they created

### What Leaders CANNOT Do

- Promote or demote other members
- Remove members from the club
- View emergency contacts

### Test Checklist

```
[ ] Can see join code at top of Members view
[ ] "Create Event" button appears in Events tab
[ ] Can create an event with title, date, location, gear requirements
[ ] Can edit an event after creating it
[ ] Cannot see "Promote to Leader" option on any member
[ ] Cannot see "View Emergency Contact" option
```

---

## Scenario 3: Founder Experience

> Sign in as **founder@test.com**

### Full Control

Founders have complete control over the club:

- See and share the join code
- Create, edit, delete any event
- Promote members to Leader
- Demote leaders to Member
- Remove anyone from the club
- View emergency contacts for members who signed waivers

### Member Management Test

1. Go to Members tab
2. Tap on a regular member
3. You should see options:
   - Promote to Leader
   - View Emergency Contact (if waiver signed)
   - Remove from Club
4. Tap on a leader
5. You should see:
   - Demote to Member
   - View Emergency Contact
   - Remove from Club

### Test Checklist

```
[ ] Can promote member@test.com to Leader
[ ] Can demote them back to Member
[ ] Can view emergency contact info
[ ] Emergency contact has "Call Now" button that opens dialer
[ ] Can remove a member (test with a throwaway account)
[ ] Warning appears if trying to leave as Founder
```

---

## Scenario 4: Free vs Pro Features

> Compare **member@test.com** (Free) vs **pro@test.com** (Pro)

### Training Plans

| Action | Free User | Pro User |
|--------|-----------|----------|
| View generated plan | Yes | Yes |
| Start workout from plan | Paywall appears | Starts immediately |

### During Workout

| Feature | Free | Pro |
|---------|------|-----|
| Basic tracking | Yes | Yes |
| Audio coaching | No | Yes |
| Heart rate zones | No | Yes |
| Interval timers | No | Yes |

### Share Card (Propaganda Mode)

| Feature | Free | Pro |
|---------|------|-----|
| Basic share card | Yes | Yes |
| Toggle calories/weight/elevation | Yes | Yes |
| Tonnage hero metric | Locked | Yes |
| Club badge | Locked | Yes |

### Free User Test Checklist

```
[ ] Can view training plan
[ ] Paywall appears when tapping "Start Workout"
[ ] Paywall shows monthly ($4.99) and yearly ($39.99) options
[ ] "Use Free Version" button dismisses paywall
[ ] Can complete Open Ruck without restrictions
[ ] Share card works but Propaganda Mode options are locked
```

### Pro User Test Checklist

```
[ ] PRO badge appears in profile/settings
[ ] Can start workout from plan directly
[ ] Audio coaching plays during workout
[ ] Propaganda Mode toggles work (tonnage + club badge)
[ ] Share card shows tonnage calculation (weight × distance)
[ ] Share card shows "TRAINING WITH [CLUB NAME]"
```

---

## Scenario 5: Ambassador Program

> Sign in as Founder of a club

### Qualification

You become an Ambassador when:
- You are the **Founder** of a club
- That club has **5 or more members** (including you)

### Test the Flow

1. Create a new club (or use existing)
2. Note your premium status (should be Free)
3. Have 4 other accounts join your club
4. Check premium status again
5. You should now have Ambassador status with free Pro access

### Ambassador Test Checklist

```
[ ] With 4 members (below threshold): No Ambassador status
[ ] With 5 members: Ambassador status activates
[ ] AMBASSADOR badge appears (not PRO badge)
[ ] Pro features work without subscription
[ ] If members leave and drop below 5: Status revoked
[ ] If members rejoin back to 5: Status restored
```

---

## Scenario 6: Event Flow

> Sign in as **leader@test.com** or **founder@test.com**

### Create an Event

1. Go to Events tab
2. Tap "Create Event"
3. Fill in:
   - Event title (required)
   - Date and time (required)
   - Address / location
   - Meeting point description ("Park behind the Wendy's")
   - Gear requirements (weight, water, headlamp, etc.)
4. Tap Create

### RSVP Flow (as any member)

1. Tap on the event
2. See event details: map, time, gear requirements
3. Tap RSVP button
4. Select: Going / Maybe / Out
5. If Going: Enter your ruck weight
6. Confirm

### The Wire

1. Scroll to comments section on event
2. Post a message
3. Should appear with your name and timestamp

### Notifications

1. RSVP "Going" to a future event
2. A notification should be scheduled for 1 hour before
3. If you change to "Out", notification should cancel

### Event Test Checklist

```
[ ] Can create event with all fields
[ ] Event shows on calendar/list view
[ ] Map displays correct location
[ ] RSVP buttons work (Going/Maybe/Out)
[ ] Weight declaration appears for "Going"
[ ] Attendee list shows RSVPs with declared weights
[ ] Group tonnage calculates correctly
[ ] Wire comments work
[ ] 1-hour reminder notification fires
```

---

## Quick Reference: Who Can Do What

| Action | Member | Leader | Founder |
|--------|--------|--------|---------|
| View events | ✓ | ✓ | ✓ |
| RSVP to events | ✓ | ✓ | ✓ |
| Post to Wire | ✓ | ✓ | ✓ |
| View club feed | ✓ | ✓ | ✓ |
| See join code | | ✓ | ✓ |
| Create events | | ✓ | ✓ |
| Edit/delete events | | ✓ | ✓ |
| Promote to Leader | | | ✓ |
| Demote to Member | | | ✓ |
| Remove members | | | ✓ |
| View emergency contacts | | | ✓ |

---

## Debugging

### Check a user's role

```sql
SELECT p.username, cm.role, c.name 
FROM club_members cm
JOIN profiles p ON p.id = cm.user_id
JOIN clubs c ON c.id = cm.club_id
WHERE p.username = 'testuser';
```

### Check Ambassador eligibility

```sql
SELECT c.name, c.member_count
FROM clubs c
JOIN club_members cm ON cm.club_id = c.id
WHERE cm.user_id = 'your-uuid' 
  AND cm.role = 'founder'
  AND c.member_count >= 5;
```

### Force refresh premium status (iOS code)

```swift
await PremiumManager.shared.checkAmbassadorStatus()
```
