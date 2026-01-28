# MARCH v2.0 - Role & Permissions Testing Guide

This guide walks through testing all role-based permissions and subscription tier features.

---

## Test Setup

### Required Test Accounts

Create these accounts in your test environment:

| Account | Email | Role | Subscription |
|---------|-------|------|--------------|
| Founder Test | founder@test.com | Founder of "Test Ruck Club" | Free |
| Leader Test | leader@test.com | Leader in "Test Ruck Club" | Free |
| Member Test | member@test.com | Member of "Test Ruck Club" | Free |
| Pro User | pro@test.com | Member of "Test Ruck Club" | Pro (Monthly) |
| Ambassador | ambassador@test.com | Founder of club with 5+ members | Ambassador |

### Test Club Setup

1. Sign in as `founder@test.com`
2. Create club "Test Ruck Club"
3. Note the join code
4. Sign in as other accounts and join using the code
5. As Founder, promote `leader@test.com` to Leader role

---

## Part 1: Club Role Testing

### Test 1.1: Founder Permissions

**Sign in as: `founder@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| View join code | Open club → Members | Join code visible at top | ☐ |
| Promote to Leader | Members → Tap member → "Promote to Leader" | Member becomes Leader | ☐ |
| Demote to Member | Members → Tap leader → "Demote to Member" | Leader becomes Member | ☐ |
| Remove member | Members → Tap member → "Remove from Club" | Member removed from club | ☐ |
| View emergency contact | Members → Tap member (with waiver) → "View Emergency Contact" | Contact info displayed | ☐ |
| Create event | Events tab → "Create Event" | Event creation form opens | ☐ |
| Edit event | Events → Tap event → Edit | Can modify event details | ☐ |
| Delete event | Events → Tap event → Delete | Event removed | ☐ |

### Test 1.2: Leader Permissions

**Sign in as: `leader@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| View join code | Open club → Members | Join code visible | ☐ |
| Cannot promote/demote | Members → Tap any member | No promote/demote options | ☐ |
| Cannot remove members | Members → Tap any member | No remove option | ☐ |
| Cannot view emergency contacts | Members → Tap member with waiver | No emergency contact option | ☐ |
| Create event | Events tab → "Create Event" | Event creation form opens | ☐ |
| Edit own event | Events → Tap own event → Edit | Can modify event | ☐ |
| RSVP to event | Events → Tap event → RSVP | Can set Going/Maybe/Out | ☐ |

### Test 1.3: Member Permissions

**Sign in as: `member@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Cannot see join code | Open club → Members | Join code NOT visible | ☐ |
| Cannot manage members | Members → Tap any member | No management options | ☐ |
| Cannot create events | Events tab | No "Create Event" button | ☐ |
| View events | Events tab | Can see all club events | ☐ |
| RSVP to event | Events → Tap event → RSVP | Can set Going/Maybe/Out + weight | ☐ |
| Post to Wire | Events → Tap event → Comment | Can post comments | ☐ |
| View feed | Feed tab | Can see club activity | ☐ |
| Post workout | Complete workout | Workout appears in feed | ☐ |
| View leaderboard | Leaderboard tab | Can see rankings | ☐ |

---

## Part 2: Event System Testing

### Test 2.1: Event Creation (Founder/Leader)

**Sign in as: `founder@test.com` or `leader@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Create basic event | Events → Create → Fill title + date | Event created | ☐ |
| Add location | Create event → Set address + map pin | Location saved, map shows pin | ☐ |
| Add meeting point | Create event → Fill meeting description | "Park behind Wendy's" shows | ☐ |
| Add gear requirements | Create event → Set weight + water | Requirements shown on event | ☐ |
| Date validation | Create event → Set past date | Should prevent/warn | ☐ |

### Test 2.2: RSVP Flow

**Sign in as: `member@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| RSVP Going | Event → RSVP → "I'm In" | Status shows Going | ☐ |
| Declare weight | RSVP → Enter weight → Confirm | Weight shown in attendee list | ☐ |
| Change RSVP | Event → RSVP → "Maybe" | Status updates to Maybe | ☐ |
| RSVP Out | Event → RSVP → "Out" | Status shows Out | ☐ |
| Group tonnage | View event with multiple Going RSVPs | Total tonnage calculated | ☐ |

### Test 2.3: The Wire (Event Comments)

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Post comment | Event → Wire → Type message → Send | Comment appears in thread | ☐ |
| View comments | Event → Scroll to Wire section | All comments visible with timestamps | ☐ |
| Comment shows author | Post comment | Username/display name shown | ☐ |

### Test 2.4: Event Notifications

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Allow notifications | When prompted, allow notifications | Permission granted | ☐ |
| RSVP Going schedules notification | RSVP Going to event | Notification scheduled for 1hr before | ☐ |
| RSVP Out cancels notification | Change RSVP to Out | Notification cancelled | ☐ |
| Notification fires | Wait until 1hr before event | Push notification received | ☐ |

---

## Part 3: Waiver System Testing

### Test 3.1: Waiver Flow

**Sign in as: `member@test.com` (new to club)**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Waiver required | Try to join club or RSVP | Waiver sheet appears | ☐ |
| Safety briefing | Waiver Step 1 | Must scroll to continue | ☐ |
| Emergency contact | Waiver Step 2 | Name + phone required | ☐ |
| Digital signature | Waiver Step 3 | Tap to sign | ☐ |
| Waiver saves | Complete waiver | `waiver_signed_at` set in DB | ☐ |
| Waiver badge | View member in list | Checkmark/shield shows | ☐ |

### Test 3.2: Emergency Contact Access

**Sign in as: `founder@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| View emergency contact | Members → Tap waiver-signed member | "View Emergency Contact" option | ☐ |
| Contact details shown | Tap "View Emergency Contact" | Name + phone displayed | ☐ |
| Call button works | Tap "Call Now" | Phone dialer opens | ☐ |

---

## Part 4: Subscription Tier Testing

### Test 4.1: Free User Limitations

**Sign in as: `member@test.com` (Free tier)**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| View training plan | Plan tab | Can see generated plan | ☐ |
| Cannot start workout | Plan → Tap workout | Paywall appears | ☐ |
| Basic Open Ruck | Main → Start Ruck | Can track basic workout | ☐ |
| No audio coaching | During workout | No audio cues | ☐ |
| Standard share card | Share workout | Basic card (no tonnage hero) | ☐ |
| Propaganda Mode locked | Share → Propaganda Mode section | Shows "Upgrade to Pro" | ☐ |
| Club leaderboard | Leaderboard tab | Can view club rankings | ☐ |
| Global leaderboard locked | Try to access global | Shows Pro required | ☐ |

### Test 4.2: Pro User Features

**Sign in as: `pro@test.com` (Pro subscription)**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Start workout from plan | Plan → Tap workout | Workout starts immediately | ☐ |
| Audio coaching | During workout | Hears audio cues | ☐ |
| Propaganda Mode | Share → Toggle Tonnage | Tonnage hero metric shows | ☐ |
| Club badge on share | Share → Toggle Club Badge | "TRAINING WITH [CLUB]" shows | ☐ |
| Global leaderboard | Leaderboard → Global tab | Can view global rankings | ☐ |
| Pro badge | Profile/settings | PRO badge displayed | ☐ |

### Test 4.3: Paywall Flow

**Sign in as: `member@test.com` (Free tier)**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Paywall appears | Tap locked feature | Paywall modal shows | ☐ |
| Features listed | View paywall | All Pro features listed | ☐ |
| Monthly option | View pricing | $4.99/month shown | ☐ |
| Yearly option | View pricing | $39.99/year with savings % | ☐ |
| Maybe Later | Tap "Use Free Version" | Paywall dismisses, stays on free | ☐ |
| Restore purchases | Tap "Restore Purchases" | Checks for existing subscription | ☐ |

---

## Part 5: Ambassador Testing

### Test 5.1: Ambassador Qualification

**Sign in as: `ambassador@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Create club | Create new club | Becomes Founder | ☐ |
| Invite 4 members | Share join code, 4 people join | 5 total members (including self) | ☐ |
| Ambassador activates | Check premium status | `isAmbassador = true` | ☐ |
| Pro features unlock | Try Pro feature | Works without subscription | ☐ |
| Ambassador badge | Profile/settings | AMBASSADOR badge (not PRO) | ☐ |
| "Club Leader Perk" | Premium status view | Shows "Free Pro Access" | ☐ |

### Test 5.2: Ambassador Revocation

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Members leave | 2 members leave club (drops to 3) | Ambassador status remains | ☐ |
| Below threshold | 3rd member leaves (drops to 2) | Ambassador status revoked | ☐ |
| Pro features locked | Try Pro feature | Paywall appears | ☐ |
| Regain status | 3 new members join (back to 5) | Ambassador status restored | ☐ |

---

## Part 6: Share Card Testing

### Test 6.1: Standard Share Card (Free)

**Sign in as: `member@test.com` (Free tier)**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Generate card | Complete workout → Share | Card generated with stats | ☐ |
| Toggle calories | Share → Toggle "Show calories" | Calories shown/hidden | ☐ |
| Toggle weight | Share → Toggle "Show weight" | Weight shown/hidden | ☐ |
| Toggle elevation | Share → Toggle "Show elevation" | Elevation shown/hidden | ☐ |
| Square format | Share → Toggle "Square format" | Card changes to 1080x1080 | ☐ |
| Share to Instagram | Tap "Share to Instagram Story" | Opens Instagram with card | ☐ |
| System share | Tap "Share or Save" | iOS share sheet opens | ☐ |

### Test 6.2: Propaganda Mode (Pro)

**Sign in as: `pro@test.com`**

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Tonnage toggle | Share → Propaganda Mode → Tonnage | Large tonnage metric appears | ☐ |
| Tonnage calculation | Check tonnage value | = Weight × Distance | ☐ |
| Club badge toggle | Share → Propaganda Mode → Club Badge | "TRAINING WITH [CLUB]" at bottom | ☐ |
| Caption includes tonnage | Check generated caption | "XXX lb-mi tonnage" in text | ☐ |
| Caption includes club | Check generated caption | "Training with [Club]" in text | ☐ |

---

## Part 7: Edge Cases

### Test 7.1: Role Transitions

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Founder leaves | Founder tries to leave club | Warning: must transfer ownership or delete | ☐ |
| Leader demoted | Leader demoted while viewing admin features | UI updates, options disappear | ☐ |
| Member promoted | Member promoted to Leader | Can now create events | ☐ |

### Test 7.2: Subscription Transitions

| Test | Steps | Expected Result | Pass/Fail |
|------|-------|-----------------|-----------|
| Subscribe while in app | Purchase Pro subscription | Features unlock immediately | ☐ |
| Subscription expires | Let subscription lapse | Features lock, paywall appears | ☐ |
| Ambassador + Subscriber | Have both active | Subscription takes precedence | ☐ |

---

## Test Results Summary

| Section | Tests Passed | Tests Failed | Notes |
|---------|--------------|--------------|-------|
| 1. Club Roles | /18 | | |
| 2. Event System | /14 | | |
| 3. Waiver System | /8 | | |
| 4. Subscription Tiers | /16 | | |
| 5. Ambassador | /8 | | |
| 6. Share Cards | /12 | | |
| 7. Edge Cases | /5 | | |
| **TOTAL** | **/81** | | |

---

## Debugging Tips

### Check Role in Database
```sql
SELECT cm.role, p.username, c.name 
FROM club_members cm
JOIN profiles p ON p.id = cm.user_id
JOIN clubs c ON c.id = cm.club_id
WHERE p.username = 'testuser';
```

### Check Subscription Status
```sql
SELECT * FROM user_subscriptions 
WHERE user_id = 'uuid-here' 
ORDER BY created_at DESC;
```

### Check Ambassador Eligibility
```sql
SELECT c.name, c.member_count, cm.role
FROM clubs c
JOIN club_members cm ON cm.club_id = c.id
WHERE cm.user_id = 'uuid-here' 
  AND cm.role = 'founder'
  AND c.member_count >= 5;
```

### Force Refresh Premium Status (iOS)
```swift
// In debug console or test code
await PremiumManager.shared.checkAmbassadorStatus()
```
