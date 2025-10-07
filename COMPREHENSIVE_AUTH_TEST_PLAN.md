# Comprehensive Authentication & Premium Test Plan

## Overview
This document provides a comprehensive test plan for all authentication scenarios in RuckTracker, covering the simplified 2-tier user system with independent premium status.

---

## User Types

### 1. **App User** (Anonymous)
- Has Supabase session but no email
- Data saved locally and synced to Supabase (tied to anonymous ID)
- Can have premium subscription (via Apple ID)
- Cannot sign out (would lose data)

### 2. **Connected User**
- Has Supabase session WITH email
- Data synced to cloud, accessible from other devices
- Can have premium subscription (via Apple ID)
- Can sign out (disconnect account)

### 3. **Premium Status** (Overlay on either type)
- Determined SOLELY by StoreKit subscription
- Tied to device's Apple ID, NOT email
- Persists across sign in/sign out
- Independent of authentication state

---

## Test Scenarios

### A. First Launch (New User)

#### Test A1: Fresh Install
**Steps:**
1. Delete app completely
2. Reinstall app
3. Launch app

**Expected Results:**
- ✅ App launches immediately (no auth wall)
- ✅ Anonymous session auto-created
- ✅ Console shows: "Created new anonymous session (App User)"
- ✅ User can start using app immediately
- ✅ Profile shows: Status = "Free", Connection = "App User" (orange)

**Verify:**
- [ ] No authentication blocking screen
- [ ] User ID created and logged
- [ ] Can create workouts
- [ ] Can access all free features

---

### B. App User (Anonymous) Scenarios

#### Test B1: App User Uses App
**Starting State:** Fresh anonymous user

**Steps:**
1. Create 3 workouts
2. Navigate to profile
3. Check profile status

**Expected Results:**
- ✅ Workouts saved successfully
- ✅ Profile shows "App User" status (orange indicator)
- ✅ "Connect Account" button visible
- ✅ NO "Disconnect" button visible
- ✅ Info text: "Your data is saved on this device..."

**Verify:**
- [ ] Workouts persist across app restarts
- [ ] User ID remains the same across restarts
- [ ] Cannot sign out

---

#### Test B2: App User Purchases Premium
**Starting State:** Anonymous user (App User)

**Steps:**
1. Navigate to premium paywall
2. Purchase yearly subscription (test mode)
3. Complete purchase
4. Return to profile

**Expected Results:**
- ✅ Purchase completes successfully
- ✅ Premium status immediately updates to "Premium"
- ✅ Console shows: "Premium status updated: Premium"
- ✅ Profile shows: Status = "Premium" (green), Connection = "App User" (orange)
- ✅ Post-purchase prompt shows "Connect Account"
- ✅ Can access all premium features
- ✅ Still shows as "App User" (not connected)

**Verify:**
- [ ] Premium features unlocked
- [ ] Training programs accessible
- [ ] Advanced analytics visible
- [ ] Premium badge shows in profile
- [ ] User still anonymous (no email)
- [ ] Cannot sign out (still anonymous)

---

#### Test B3: App User Premium Connects Account
**Starting State:** Anonymous user with premium subscription

**Steps:**
1. From post-purchase prompt OR profile, tap "Connect Account"
2. Enter email: `test@example.com`
3. Enter password: `testpass123`
4. Confirm password
5. Tap "Connect Account"

**Expected Results:**
- ✅ Email linking succeeds
- ✅ Console shows: "Successfully upgraded anonymous account"
- ✅ Profile updates: Status = "Premium" (green), Connection = "Connected" (green)
- ✅ Same user ID (data not lost)
- ✅ Email confirmation sent
- ✅ "Disconnect Account" button now visible
- ✅ Premium status maintained

**Verify:**
- [ ] All existing workouts still visible
- [ ] User ID unchanged
- [ ] Premium still active
- [ ] Can now sign out
- [ ] Email shown in profile

---

#### Test B4: App User Tries to Sign Out
**Starting State:** Anonymous user (no email)

**Steps:**
1. Navigate to profile
2. Look for sign out option

**Expected Results:**
- ✅ NO "Disconnect Account" button visible
- ✅ Only "Connect Account" button shown
- ✅ Cannot sign out
- ✅ Data protected from loss

**Verify:**
- [ ] No sign out option available
- [ ] User session persists

---

### C. Connected User Scenarios

#### Test C1: Connected User Signs Out
**Starting State:** User with email connected

**Steps:**
1. Navigate to profile
2. Tap "Disconnect Account"
3. Confirm alert
4. Wait for process to complete

**Expected Results:**
- ✅ Alert shows: "Disconnecting will create a new anonymous session..."
- ✅ Alert mentions premium tied to Apple ID
- ✅ Sign out succeeds
- ✅ NEW anonymous session created (different user ID)
- ✅ Console shows: "Created new anonymous session after sign out"
- ✅ Profile shows: Status = depends on Apple ID subscription, Connection = "App User"
- ✅ Fresh start with new anonymous account

**Verify:**
- [ ] New user ID generated
- [ ] Old data not accessible (new session)
- [ ] Premium status based on device's Apple ID
- [ ] Can continue using app
- [ ] No authentication wall appears

---

#### Test C2: Connected Free User
**Starting State:** User with email, no subscription

**Steps:**
1. Sign in with email/password
2. Check profile status
3. Try accessing premium feature

**Expected Results:**
- ✅ Profile shows: Status = "Free", Connection = "Connected" (green)
- ✅ Premium features show paywall
- ✅ Can sign out
- ✅ Email displayed in profile

**Verify:**
- [ ] Premium features locked
- [ ] Paywall appears for premium content
- [ ] Can disconnect account

---

#### Test C3: Connected Premium User
**Starting State:** User with email AND active subscription

**Steps:**
1. Sign in with email/password
2. Have active subscription on device
3. Check profile and features

**Expected Results:**
- ✅ Profile shows: Status = "Premium" (green), Connection = "Connected" (green)
- ✅ All premium features accessible
- ✅ Premium badge visible
- ✅ Subscription expiry date shown
- ✅ Can sign out

**Verify:**
- [ ] Training programs accessible
- [ ] Advanced analytics visible
- [ ] Leaderboards accessible
- [ ] Premium badge in multiple views
- [ ] Can disconnect account

---

### D. Sign In / Sign Out Cycles

#### Test D1: Sign Out Then Sign In Same Account
**Starting State:** Connected premium user

**Steps:**
1. Sign out (disconnect)
2. Note: New anonymous session created
3. Navigate to profile
4. Tap "Connect Account"
5. Sign in with same email/password

**Expected Results:**
- ✅ After sign out: New anonymous user ID, premium depends on Apple ID
- ✅ Sign in succeeds
- ✅ Returns to original user ID and data
- ✅ Premium status restored (if had subscription)
- ✅ All old workouts accessible

**Verify:**
- [ ] Data from before sign out restored
- [ ] Premium status matches subscription
- [ ] Workout history intact

---

#### Test D2: Multiple Sign Out/In Cycles
**Starting State:** Connected user

**Steps:**
1. Sign out
2. Sign in
3. Sign out
4. Sign in

**Expected Results:**
- ✅ Each sign out creates NEW anonymous session
- ✅ Each sign in restores correct user data
- ✅ Premium status consistent with Apple ID
- ✅ No data loss
- ✅ No memory leaks

**Verify:**
- [ ] App remains stable
- [ ] No duplicate data
- [ ] Sessions managed correctly

---

### E. Premium Status Scenarios

#### Test E1: Premium Persists After Sign Out
**Starting State:** Connected user with premium

**Steps:**
1. Verify premium features accessible
2. Sign out
3. Check premium status in new anonymous session

**Expected Results:**
- ✅ After sign out: Premium status maintained (if subscription tied to Apple ID)
- ✅ Premium features still accessible
- ✅ Console shows: "Premium is tied to Apple ID, not authentication"

**Verify:**
- [ ] Training programs still accessible
- [ ] Premium badge still shows
- [ ] Subscription tied to device Apple ID

---

#### Test E2: Subscription Expires
**Starting State:** User with expired subscription

**Steps:**
1. Wait for subscription to expire (or simulate in sandbox)
2. Check premium status

**Expected Results:**
- ✅ Premium status updates to "Free"
- ✅ Premium features locked
- ✅ Paywall appears
- ✅ Console shows: "Subscription expired"

**Verify:**
- [ ] Premium features immediately locked
- [ ] User notified of expiration
- [ ] Upgrade option presented

---

#### Test E3: Purchase Premium as Connected User
**Starting State:** Connected user, no subscription

**Steps:**
1. Navigate to paywall
2. Purchase subscription
3. Complete purchase

**Expected Results:**
- ✅ Purchase succeeds
- ✅ Premium status updates immediately
- ✅ No post-purchase prompt (already connected)
- ✅ Premium features unlocked

**Verify:**
- [ ] Immediate access to premium
- [ ] No redundant account prompts
- [ ] Subscription synced

---

### F. Edge Cases

#### Test F1: App Restart During Anonymous Session
**Starting State:** Anonymous user with workouts

**Steps:**
1. Create 2 workouts
2. Force quit app
3. Relaunch app

**Expected Results:**
- ✅ Same anonymous session restored
- ✅ Same user ID
- ✅ Workouts still visible
- ✅ No new session created

**Verify:**
- [ ] User ID unchanged
- [ ] Data persists
- [ ] No data loss

---

#### Test F2: Network Loss During Sign In
**Starting State:** Anonymous user

**Steps:**
1. Disable network
2. Try to connect account
3. Enter email/password
4. Submit

**Expected Results:**
- ✅ Error message shown
- ✅ User remains anonymous
- ✅ Can retry when network returns
- ✅ No data loss

**Verify:**
- [ ] Graceful error handling
- [ ] User can retry
- [ ] Session stable

---

#### Test F3: Email Already In Use
**Starting State:** Anonymous user

**Steps:**
1. Try to connect with email already used by another account
2. Submit

**Expected Results:**
- ✅ Error: "Email already in use"
- ✅ User remains anonymous
- ✅ Can try different email
- ✅ Session stable

**Verify:**
- [ ] Clear error message
- [ ] No session disruption
- [ ] Can use different email

---

#### Test F4: Invalid Email Format
**Starting State:** Anonymous user

**Steps:**
1. Try to connect with invalid email: "notanemail"
2. Submit

**Expected Results:**
- ✅ Client-side validation catches error
- ✅ Error: "Please enter a valid email"
- ✅ Cannot submit invalid email

**Verify:**
- [ ] Validation before submission
- [ ] Clear error message
- [ ] Button disabled for invalid input

---

#### Test F5: Simultaneous Devices Same Apple ID
**Starting State:** Premium subscription on Apple ID

**Steps:**
1. Install app on Device A
2. Install app on Device B (same Apple ID)
3. Both start as anonymous
4. Check premium status on both

**Expected Results:**
- ✅ Both devices show premium (tied to Apple ID)
- ✅ Different anonymous user IDs
- ✅ Independent data until connected
- ✅ If connect same email on both: data syncs

**Verify:**
- [ ] Premium on both devices
- [ ] Independent until connected
- [ ] Sync works after connecting

---

### G. UI/UX Verification

#### Test G1: Profile View States
**Test all profile view variations:**

| User Type | Premium | Connection | Status Badge | Connection Badge | Action Button |
|-----------|---------|------------|--------------|------------------|---------------|
| App User | No | No | "Free" (orange) | "App User" (orange) | "Connect Account" |
| App User | Yes | No | "Premium" (green) | "App User" (orange) | "Connect Account" |
| Connected | No | Yes | "Free" (blue) | "Connected" (green) | "Disconnect Account" |
| Connected | Yes | Yes | "Premium" (green) | "Connected" (green) | "Disconnect Account" |

**Verify:**
- [ ] All badge colors correct
- [ ] Correct action buttons shown
- [ ] No "Guest" or "Sign Out" terminology
- [ ] Clear connection status indicators

---

#### Test G2: Terminology Consistency
**Check all views for correct terminology:**

**Should NEVER appear:**
- ❌ "Guest User"
- ❌ "Guest Account"
- ❌ "Sign Out" (for anonymous)
- ❌ "Anonymous User" (user-facing)

**Should appear:**
- ✅ "App User" (for anonymous)
- ✅ "Connected" (for email users)
- ✅ "Connect Account" (action)
- ✅ "Disconnect Account" (action for connected)

**Verify:**
- [ ] ProfileView uses correct terms
- [ ] PostPurchasePrompt uses correct terms
- [ ] No old terminology remains

---

### H. Console Logging Verification

#### Test H1: Log Quality
**Check console output during operations:**

**Starting Session:**
```
📱 ContentView appeared
📱 Authentication state: App User
🔐 Checking for existing session...
✅ Created new anonymous session (App User)
✅ User ID: [UUID]
```

**Premium Purchase:**
```
🔍 Checking subscription status...
✅ Active subscription found
🔐 Premium status updated: Premium
🔐 StoreKit subscription: true
```

**Sign Out:**
```
🔄 Starting sign out process...
✅ User can sign out - proceeding...
✅ Signed out connected user
✅ Created new anonymous session after sign out
📊 New anonymous session - User ID: [UUID]
🔐 Sign out detected - premium status remains unchanged
```

**Verify:**
- [ ] Logs are clear and helpful
- [ ] No confusing/contradictory messages
- [ ] Emojis make logs scannable
- [ ] User IDs logged for debugging

---

## Critical Success Criteria

### Must Pass:
1. ✅ No authentication wall on first launch
2. ✅ Anonymous users can use app fully
3. ✅ Anonymous users with premium can access premium features
4. ✅ Anonymous users cannot sign out (data protection)
5. ✅ Connected users can sign out
6. ✅ Premium status independent of authentication
7. ✅ Sign out creates new anonymous session (not auth wall)
8. ✅ Premium persists across sign out (tied to Apple ID)
9. ✅ No "Guest" terminology in UI
10. ✅ Data not lost during state transitions

### Performance Requirements:
- Session creation: < 2 seconds
- Sign out/sign in: < 3 seconds
- Premium status check: < 1 second
- No memory leaks during repeated sign out/in

---

## Test Execution Checklist

### Pre-Testing Setup:
- [ ] Test in Xcode Simulator
- [ ] Test on physical device
- [ ] Test with StoreKit sandbox enabled
- [ ] Test with valid/expired test subscriptions
- [ ] Clear app data between major tests

### Testing Order:
1. First Launch (Test A1)
2. App User Scenarios (Tests B1-B4)
3. Premium Purchase (Tests B2, E3)
4. Account Connection (Test B3)
5. Sign Out/In Cycles (Tests D1-D2)
6. Premium Persistence (Tests E1-E2)
7. Edge Cases (Tests F1-F5)
8. UI/UX Verification (Tests G1-G2)
9. Console Logging (Test H1)

### Regression Testing:
After any auth-related code changes, rerun:
- [ ] Test A1 (Fresh install)
- [ ] Test B2 (Anonymous premium)
- [ ] Test B3 (Connect account)
- [ ] Test D1 (Sign out/in)
- [ ] Test E1 (Premium persistence)
- [ ] Test G1 (Profile states)

---

## Bug Reporting Template

**Title:** [Brief description]

**User Type:** App User / Connected User / Premium

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Result:**


**Actual Result:**


**Console Output:**
```
[paste relevant logs]
```

**Impact:** Critical / High / Medium / Low

---

## Notes for Testers

1. **User ID Tracking**: Note user IDs in console - they should change on sign out, restore on sign in
2. **Premium Independence**: Premium should work regardless of auth state
3. **Data Integrity**: Never lose user data during state transitions
4. **Terminology**: Watch for any "Guest" or "Sign Out" language for anonymous users
5. **Apple ID**: Remember premium is tied to Apple ID, not app authentication

---

## Success Metrics

- **0 authentication walls** for new users
- **100% data retention** during state transitions
- **< 3 second** sign in/out operations
- **0 crashes** during auth operations
- **Clear user journey** with intuitive terminology

---

## Known Limitations

1. Anonymous users lose data if they don't connect and switch devices
2. Premium purchases require Apple ID (can't transfer to different Apple ID)
3. Email verification may be required (depending on Supabase config)
4. Multiple devices with same email = shared data (by design)

---

**Last Updated:** October 7, 2025
**Version:** 1.0
**Status:** Ready for Testing

