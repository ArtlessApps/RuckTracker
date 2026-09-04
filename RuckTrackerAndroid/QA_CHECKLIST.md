# MARCH Android — QA Checklist

Print this or copy into Notes. Test on a **physical Android phone** (API 26+) unless noted. Use the **same Supabase account** as iOS for cross-platform checks.

**Tester:** _______________  
**Device:** _______________  
**Android version:** _______________  
**Build:** _______________ (debug / internal testing)  
**Date:** _______________

---

## Setup (before testing)

- [ ] Android Studio installed; project opens and Gradle syncs
- [ ] App runs on physical device via Run or internal testing install
- [ ] Location permission granted (Allow all the time for background rucks)
- [ ] Notification permission granted
- [ ] Health Connect installed + HR permission granted (optional)
- [ ] Signed in with test account: _______________
- [ ] iOS device available for side-by-side comparison (same account)

---

## A. App shell & navigation

- [ ] App launches without crash (splash → auth or main)
- [ ] **Ruck** tab loads
- [ ] **Plan** tab loads
- [ ] **Tribe** tab loads
- [ ] **Rankings** tab loads
- [ ] **You** tab loads
- [ ] Dark MARCH theme renders correctly (green accent, dark background)
- [ ] Tab switching is smooth, no state loss

---

## B. Auth & onboarding

- [ ] **Sign up** with new email/username/password
- [ ] Email confirmation flow works (if Supabase requires it)
- [ ] **Sign in** with existing account
- [ ] **Sign in** with same account used on iOS — profile loads
- [ ] Username and workout count display on home
- [ ] **12-step onboarding** completes (or skip path works)
- [ ] Onboarding preferences persist after app restart
- [ ] **Sign out** returns to auth screen
- [ ] **Sign in again** — session restores, skips onboarding if already complete
- [ ] **Delete account** (throwaway account only) — account removed, signed out

---

## C. Premium & paywall

- [ ] **Start a Ruck** without Pro shows paywall
- [ ] Paywall shows monthly ($4.99) and yearly ($39.99) options
- [ ] Purchase completes (requires Play Console setup — see BILLING_TEST_SETUP.md)
- [ ] After purchase, **Start a Ruck** works
- [ ] Pro status visible in settings/account area
- [ ] **Ambassador**: founder account with 5+ members gets Pro without purchase
- [ ] Sign out / sign in — Pro status restores from Supabase

---

## D. Workout tracking (physical device, walk outdoors)

- [ ] **Start a Ruck** → weight selector (body + ruck weight)
- [ ] Location permission prompt appears if not granted
- [ ] Active workout screen: timer counts up
- [ ] Distance increases while walking
- [ ] Pace displays after ~0.01 mi
- [ ] Calories update over time
- [ ] Elevation gain updates (if device supports altitude)
- [ ] Heart rate displays (if Health Connect granted)
- [ ] **Pause** stops timer/distance accumulation
- [ ] **Resume** continues tracking
- [ ] Foreground notification visible while tracking ("Ruck in progress")
- [ ] **End** → post-workout summary shows correct stats
- [ ] Workout appears in **You → History**
- [ ] Summary stats (total workouts, distance) update on You tab
- [ ] App survives screen lock during active workout
- [ ] App survives brief background during active workout

---

## E. Cloud sync & community (signed in, member of ≥1 club)

Use club: _______________  Join code: _______________

- [ ] After ruck, workout auto-posts to club **Feed**
- [ ] Post shows distance, calories, username
- [ ] **Like** on feed post works
- [ ] Club **Leaderboard** updates with weekly distance
- [ ] **Global leaderboard** updates after ruck (Rankings tab)
- [ ] Same workout visible on iOS club feed (cross-platform)

---

## F. Plan, programs & challenges

- [ ] **Plan** tab shows week schedule after onboarding
- [ ] Sessions show distance, weight, day of week
- [ ] **Programs** catalog loads (8 programs)
- [ ] Program details show name, description, duration, difficulty
- [ ] **Challenges** catalog loads (8 challenges)
- [ ] Challenge details show name, duration, focus area
- [ ] Pro-gated program/challenge start shows paywall when not subscribed

---

## G. Tribe / clubs

### Not signed in
- [ ] Tribe tab prompts to sign in

### Signed in, no clubs
- [ ] Join by code works
- [ ] Create club works (name, description, public/private, zipcode location)
- [ ] Waiver flow on join (if applicable)

### Signed in, has clubs
- [ ] Club list displays
- [ ] Club detail: **Feed** tab
- [ ] Club detail: **Leaderboard** tab
- [ ] Club detail: **Events** tab
- [ ] **Leave club** works
- [ ] Club on Android matches club list on iOS (same account)

### Club management (founder/leader account)
- [ ] View member list
- [ ] Promote member to leader (founder only)
- [ ] Demote leader to member (founder only)
- [ ] Remove member (founder/leader)
- [ ] Edit club settings (founder)
- [ ] Regenerate join code (founder)

---

## H. Events

- [ ] Event list loads for club
- [ ] Create event (title, date, description)
- [ ] Event detail shows RSVP options
- [ ] RSVP **Going** with declared weight
- [ ] RSVP **Maybe** / **Out**
- [ ] Attendee list updates
- [ ] Event comment ("The Wire") posts
- [ ] RSVP reminder notification fires (optional — check ~1hr before if scheduled)

---

## I. Rankings

- [ ] **Road Warriors** (weekly distance) loads
- [ ] **Heavy Haulers** (all-time tonnage) loads
- [ ] **Vertical Gainers** (monthly elevation) loads
- [ ] **Iron Discipline** (30-day consistency) loads
- [ ] Current user highlighted if ranked
- [ ] Signed-out state handled gracefully

---

## J. You tab — analytics & settings

- [ ] Total workouts, distance, calories, elevation display
- [ ] Workout history list loads
- [ ] **Delete** workout removes from list and updates stats
- [ ] **Share** workout opens system share sheet with image
- [ ] Share card shows distance, ruck weight, calories, tonnage
- [ ] **Settings** panel opens
- [ ] Body weight / default ruck weight display
- [ ] **Export CSV** produces valid data
- [ ] **Send feedback** opens email to hello@artless.app
- [ ] **Sign out** works from settings
- [ ] **Delete account** works from settings (throwaway only)

---

## K. Deep links

Run from terminal with device connected:

```bash
adb shell am start -a android.intent.action.VIEW -d "rucktracker://workout/test-share-code"
```

- [ ] App opens (or comes to foreground)
- [ ] Deep link handled without crash

---

## L. Cross-platform parity (iOS vs Android, same account)

| Check | iOS | Android | Match? |
|-------|-----|---------|--------|
| Username | | | ☐ |
| Club membership | | | ☐ |
| Club feed after ruck | | | ☐ |
| Global rank (if ranked) | | | ☐ |
| Pro / Ambassador status | | | ☐ |
| Profile workout count | | | ☐ |

---

## M. Edge cases & regression

- [ ] Airplane mode during auth — graceful error
- [ ] Airplane mode during active workout — tracking continues locally
- [ ] Deny location — clear message, can't start ruck
- [ ] Kill app mid-workout — relaunch (workout may not resume; verify no crash)
- [ ] Low battery / battery saver — notification persists
- [ ] Rotate screen during workout — UI stable

---

## Sign-off

| Area | Pass | Fail | Notes |
|------|------|------|-------|
| Auth & onboarding | ☐ | ☐ | |
| Premium / billing | ☐ | ☐ | |
| Workout tracking | ☐ | ☐ | |
| Tribe / clubs | ☐ | ☐ | |
| Events | ☐ | ☐ | |
| Rankings | ☐ | ☐ | |
| Analytics / settings | ☐ | ☐ | |
| Cross-platform | ☐ | ☐ | |

**Ready for internal testing release:** ☐ Yes  ☐ No  

**Blockers:**

1. _______________
2. _______________
3. _______________
