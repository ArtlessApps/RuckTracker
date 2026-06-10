# MARCH PRD v3.0
## "Revenue First"

**Supersedes:** PRD v2.0 "Tribe Command"
**Date:** May 2026
**Last updated:** June 9, 2026
**Status:** Active

### Changelog — June 9, 2026
- **Onboarding:** Added Step 10 (Profile Creation) after payment; Permissions moved to Step 11 (12 steps total)
- **Auth:** Sign in with Apple on onboarding profile step and login sheet; `CommunityService+Apple.swift` extension
- **Settings:** Removed debug logs and onboarding status; app version reads from bundle
- **Copy:** "Already have an account? Sign in" on onboarding welcome

---

## 1. The Situation

MARCH has a working app with real differentiators — clubs, leaderboards, events, waivers, and training programs. The problem is not the product. The problem is the business model and the distribution.

**The old model:** Free tracking + paid training programs.
**Why it fails:** Users don't care enough about training programs to pay. The thing they use every ruck (tracking) is free, so the paywall never hits.

**The new model:** Match RuckWell's pricing exactly. Be a better product at the same price.
**Why it works:** RuckWell charges $4.99/month for solo tracking with no community. MARCH charges $4.99/month for tracking AND clubs, leaderboards, and community. Same price. Objectively more.

---

## 2. Competitive Snapshot

### RuckWell ($4.99/month, no free tier, no annual plan)
**Has:** Accurate GPS tracking, Strava sync, recovery scores (HRV/sleep), GPX navigation, heart rate zones, VO2 max protection, sauna/wellness tracking, Apple Watch independent recording.
**Lacks:** Community clubs, group events, leaderboards, training programs, waiver system.

### MARCH (current)
**Has:** GPS tracking, HealthKit integration, calorie adjustment for ruck weight, Apple Watch app, clubs, leaderboards, events, waivers, training programs, AI training plans, share cards.
**Lacks:** Strava sync, VO2 max protection, recovery scores, GPX navigation, independent Apple Watch recording.

### The Positioning
> "RuckWell charges $4.99/month for a solo tracker. MARCH charges $4.99/month for a solo tracker AND a community."

Same price. Objectively more value. That is the pitch everywhere — in the app, in social content, in influencer briefs.

---

## 3. Pricing

| Plan | Price | Trial | Change from v2.0 |
|---|---|---|---|
| MARCH Pro Monthly | $4.99/month | 7 days free | No change |
| MARCH Pro Yearly | $39.99/year | 7 days free | No change (RuckWell doesn't offer this — keep it) |
| Free tier | Removed | — | **Breaking change** |

### Trial Model: 7-Day Free Trial
Matches RuckWell exactly. Standard App Store auto-renewable subscription trial — already configured in `StoreKitManager.swift` and App Store Connect. No new infrastructure needed.

After 7 days, subscription required for all tracking features. Community features (clubs, viewing leaderboards) remain accessible to prevent cold churn and encourage referrals.

**Why 7 days over a usage-based limit (e.g. 3 rucks/month):**
- Already built — App Store Connect trial is live
- Time-based urgency is universally understood
- Usage-based limits punish frequent ruckers and reward infrequent ones inconsistently
- Matches the competitor model users already recognize

**Onboarding implication:** Make sure new users ruck within the first 3 days. A trial that expires before the user has experienced a single workout is dead churn. Onboarding should push toward a first ruck immediately.

**Account creation implication:** Payment (Step 9) works without an account — users can start a trial anonymously. Profile creation (Step 10) is shown immediately after payment while motivation is highest. Users who skip profile creation can still use tracking, but leaderboards and club identity require an account. Sign in with Apple is the primary path; email/password is the fallback.

### What's Behind the Paywall

| Feature | Trial (7 days) | Pro |
|---|---|---|
| GPS tracking | ✅ Full | ✅ Full |
| Ruck weight calorie adjustment | ✅ Full | ✅ Full |
| Heart rate monitoring + zones | ✅ Full | ✅ Full |
| Elevation tracking | ✅ Full | ✅ Full |
| Clubs (view + join) | ✅ | ✅ |
| Leaderboards | ✅ Global | ✅ Global |
| Share cards | ✅ Full | ✅ Full |
| Training programs | ✅ Full | ✅ Full |
| Advanced analytics (tonnage, trends) | ✅ Full | ✅ Full |
| Audio coaching | ✅ Full | ✅ Full |
| Strava sync | ✅ Full | ✅ Full |
| VO2 max protection | ✅ Full | ✅ Full |
| Recovery scores | ✅ Full | ✅ Full (Phase 2) |

**Rationale:** During trial, give users the full Pro experience. They need to feel what they're paying for before the wall hits. No feature restrictions during 7 days.

---

## 4. Feature Roadmap

### Sprint 1 — Wire Up (This Week, Hours Not Days)
These features are already coded. They just need to be connected.

**4.1 Audio Coaching**
- Status: `MarchSessionDescriptor` catalog exists with `premiumHook` fields defined. Not connected to workout flow.
- Work: Connect audio cue triggers in `WorkoutManager.swift` to fire at pace, HR zone, and distance milestones.
- Gate behind: Pro subscription.
- Why now: Low effort, immediate Pro differentiator.

**4.2 Heart Rate Zones**
- Status: `heartRateZone` computed property exists in `WorkoutManager.swift`. Not surfaced in UI.
- Work: Display current zone in `ActiveWorkoutFullScreenView`. Add zone summary to post-workout summary.
- Gate behind: Pro subscription (basic HR shown free, zones are Pro).
- Why now: Low effort. RuckWell has this. Parity.

**4.3 Activate 7-Day Free Trial Paywall**
- Status: `StoreKitManager.swift` exists. App Store Connect trial already configured at 7 days for both monthly and yearly products. Trial logic needs to gate the app UI after expiry.
- Work: After trial expires, show paywall modal on workout start. Community features (clubs, leaderboard browsing) remain accessible. Full product unlocked during trial — no restrictions.
- Why now: This is the revenue unlock. Nothing else matters until this is live.

---

### Sprint 2 — Parity Features (2–4 Weeks Each)

**4.4 Strava Sync**
- Status: Not built. Listed in original Phase 2 project plan.
- Work: OAuth 2.0 integration with Strava API. On workout completion, offer "Sync to Strava" button. Auto-sync option in settings.
- Gate behind: Pro subscription.
- Why: Single most requested feature from serious ruckers. Primary reason a user stays on RuckWell instead of switching to MARCH.
- Priority: 🔴 Highest in this sprint.

**4.5 VO2 Max Protection**
- Status: Not built. Problem is documented in project plan (elevated HR + slow pace causes Apple Watch to flag fitness decline).
- Work: On workout start, write metadata to HealthKit workout that signals "loaded carry" activity type. Prevents Apple Watch from penalizing VO2 max score.
- Gate behind: Pro subscription.
- Why: This is a real pain point for Apple Watch users. RuckWell markets this explicitly. It is a compelling reason to pay.

**4.6 Independent Apple Watch Recording**
- Status: Partial. Watch app exists but requires iPhone connection.
- Work: Enable standalone GPS session recording on Apple Watch without iPhone. Sync to iPhone on reconnect.
- Gate behind: Pro subscription.
- Why: Phone-free rucks are common. Parity with RuckWell.

---

### Sprint 3 — Expansion Features (4–8 Weeks)

**4.7 Recovery Score**
- Status: Not built.
- Work: Pull HRV, resting heart rate, sleep quality, and respiratory rate from HealthKit. Combine with recent RuckLoad (tonnage over last 7 days) to generate a 1–10 daily recovery score. Display on home screen.
- Gate behind: Pro subscription.
- Why: RuckWell's differentiator. If MARCH builds a better version (using RuckLoad as a factor, which RuckWell invented), this becomes a direct competitive win.
- Note: Do not rush this. A bad recovery score algorithm loses user trust permanently.

**4.8 GPX Route Navigation**
- Status: Not built.
- Work: Allow users to import a GPX file or draw a route. Show breadcrumb trail on map during workout. Audio cue at turn points.
- Gate behind: Pro subscription.
- Why: Useful for event prep (GORUCK courses, military routes). Not urgent — address in Sprint 3.

---

### Backlog (Do Not Build Now)

| Feature | Reason to skip |
|---|---|
| Sauna/cold plunge tracking | RuckWell's wellness angle, not MARCH's identity |
| Nutrition/macro tracking | Different product category entirely |
| No-account mode | Payment works without login, but leaderboard/club identity requires an account — profile creation is prompted post-payment (Step 10), not before |
| Android app | Large effort. Revisit after iOS revenue is proven. |

---

## 5. Growth Strategy

### Channel Priority
1. **TikTok** — Primary. New accounts get strong organic reach. Health & Fitness is top-2 category for downloads. Post daily.
2. **Instagram Reels** — Secondary. Same video, different caption. Post same day as TikTok.
3. **Everything else** — Ignore for now.

### Content Volume
- TikTok: 1 video per day minimum
- Instagram: 1 Reel per day (repurposed from TikTok)
- Goal: 30 days of consistent posting before evaluating what works

### Content Format (Faceless)
Creator is faceless. All content is POV-style rucking footage.

**Shot types to film in bulk on one ruck:**
- Boots/path POV walking
- Watch screen showing live metrics
- Hands loading/adjusting ruck weight and plates
- Time-lapse of full route
- Phone screen showing MARCH app during or after workout

Film 20–30 clips per ruck session. These clips power 2–3 weeks of content.

### Content Angle Rotation (Weekly)
| Day | Angle |
|---|---|
| Monday | Pricing: "RuckWell charges $4.99 for this. MARCH includes it." |
| Tuesday | POV ruck footage (authentic, no text) |
| Wednesday | Feature highlight (Strava sync, HR zones, clubs) |
| Thursday | Rucking tips / education (builds trust, not selling) |
| Friday | Community / clubs angle |
| Saturday | Training program or challenge content |
| Sunday | Trending sound + app screen recording |

### Content Production Workflow
1. Generate script and caption using MARCH Content Engine (Claude-powered tool, already built)
2. Edit footage in CapCut (free) — drop clips, add text overlay from generated hook, add auto-captions, add trending sound
3. Export and post manually to TikTok + Instagram

**Time per post: 15–20 minutes.**

### AI Tool Stack
- **Script/caption generation:** MARCH Content Engine (already built)
- **Video editing:** CapCut (free, AI captions, TikTok native integration)
- **Backup for no-footage days:** InVideo AI ($20/month) — prompt to stock-footage video

---

## 6. Influencer Seeding Strategy

### The Model
Give free lifetime Pro access to rucking micro-influencers. No payment. No contract. No required posts.

Pitch: *"Use it free permanently. If you like it and want to post about it, awesome. No obligation either way."*

### Target Profile
- Platform: TikTok or Instagram
- Follower count: 5K–100K (micro converts better than mega)
- Content: GORUCK event coverage, military fitness, rucking training vlogs, ruck gear reviews

### Discovery Hashtags
`#rucking` `#goruck` `#ruckclub` `#ruckingchallenge` `#goruckchallenge` `#militaryfitness` `#weightedwalking`

### Outreach Message
> Hey [Name] — love your rucking content.
>
> I built MARCH — a rucking tracker with GPS, clubs, leaderboards, and Strava sync. I'd love to give you free Pro access permanently, no strings attached.
>
> If you like it and want to post about it, awesome. If not, keep the access anyway.
>
> Let me know and I'll set you up.

### Volume Target
Reach out to 5 influencers per week. Goal: 20 active influencers using MARCH within 60 days.

### How to Give Access
Generate promo codes in App Store Connect once the $4.99 paywall is live. One code per influencer, unlimited duration.

---

## 7. Success Metrics

### Revenue (Primary)
| Metric | 30-day target | 90-day target |
|---|---|---|
| Active Pro subscribers | 50 | 250 |
| MRR | $250 | $1,250 |
| Trial starts | 200 | 1,000 |
| Trial conversion rate | 25% | 30% |
| Trial-to-first-ruck rate | >70% (onboarding KPI) | >80% |

### Growth
| Metric | 30-day target | 90-day target |
|---|---|---|
| TikTok followers | 500 | 3,000 |
| App downloads | 200 | 1,000 |
| Influencers seeded | 5 | 20 |

### Product
| Metric | Target |
|---|---|
| 3-ruck limit hit rate | >40% of new users (shows paywall is working) |
| Strava sync usage | >60% of Pro users |
| Audio coaching usage | >30% of Pro users |

---

## 8. Execution Order

| Priority | Task | Effort | Impact |
|---|---|---|---|
| 1 | Activate 7-day trial paywall gate in UI | Hours | 🔴 Revenue unlock |
| 2 | Wire up HR zones in UI | Hours | 🟡 Pro feature |
| 3 | Wire up audio coaching | Hours | 🟡 Pro feature |
| 4 | Start posting daily content | Ongoing | 🔴 Growth |
| 5 | Build Strava sync | 1–2 weeks | 🔴 Retention |
| 6 | Build VO2 max protection | 1 week | 🟡 Parity |
| 7 | Begin influencer outreach | Ongoing | 🔴 Growth |
| 8 | Independent Apple Watch recording | 2 weeks | 🟡 Parity |
| 9 | Recovery score | 4–6 weeks | 🟢 Differentiator |
| 10 | GPX navigation | 4–6 weeks | 🟡 Parity |
| 11 | Android app | 3–6 months | 🟢 Market expansion |

---

## 9. What Has NOT Changed from v2.0

The community and coordination features from PRD v2.0 "Tribe Command" remain in the product. They are not being deprioritized — they are now part of what makes MARCH worth $4.99/month when RuckWell is also $4.99/month.

Specifically, these ship as-is or continue in development:
- Club calendar and events engine
- Smart RSVPs with declared weight
- Multi-tier roles (Founder / Leader / Member)
- Ironclad waiver system
- Tonnage share card
- Tribe Badge on share cards

These features are MARCH's moat. RuckWell cannot copy them without rebuilding their entire product.

---

## 10. Onboarding Flow (Updated June 9, 2026)

Onboarding is a 12-step flow (Steps 0–11). Payment comes before account creation by design — users commit to the trial first, then are prompted to create a profile while motivation is highest.

### Step Map

| Step | Screen | Purpose |
|---|---|---|
| 0–8 | Personalization questions | Program recommendation, preferences |
| 9 | Pro Upsell (`ProUpsellStep`) | 7-day trial / subscription — **works without an account** |
| 10 | Profile Creation (`ProfileCreationStep`) | **New.** Post-payment signup — Apple or email/password |
| 11 | Permissions (`PermissionsStep`) | HealthKit permissions → `hasCompletedOnboarding = true` |

### Profile Creation (Step 10)

Shown immediately after payment. Two signup paths:

1. **Continue with Apple** (primary) — one tap, no password. Supabase email confirmation is disabled; session is instant.
2. **Email + password** (fallback) — username, email, password (6+ chars).

**Apple flow:**
- New Apple user → lightweight username picker ("One last thing") → advance to Step 11
- Returning Apple user → skip straight to Step 11
- User dismisses Apple sheet → no error shown (`.canceled` is ignored)

**Skip:** "Skip for now" advances to permissions without creating an account. Tracking works; leaderboard identity does not.

**Copy:** Welcome screen link reads "Already have an account? Sign in" (opens `AuthenticationView` sheet).

### Returning Users (`AuthenticationView`)

The login sheet (opened from onboarding welcome or Settings) now includes the same Apple Sign In button above the email/password form. This covers users who originally signed up with Apple and reinstall — they may not have a password.

- Apple button + "or" divider + email/password form
- New Apple users in this context → username picker → dismiss on success
- Returning Apple users → dismiss immediately

### Implementation

| File | Role |
|---|---|
| `ProfileCreationStep.swift` | Step 10 UI — Apple button, email form, username picker phase |
| `CommunityService+Apple.swift` | `signInWithApple()`, `setUsernameAfterAppleSignIn()` |
| `PhoneOnboardingView.swift` | 12-step flow, progress bar, step wiring |
| `CommunityTribeView.swift` | `AuthenticationView` with Apple Sign In |

**Requirements:** Sign In with Apple capability enabled in `RuckTracker.entitlements`. Supabase Apple provider configured. Email confirmation disabled in Supabase for instant signup.

---

## 11. Settings & Production Polish (Updated June 9, 2026)

Settings cleaned up for production release:

| Change | Rationale |
|---|---|
| Removed "View Debug Logs" | Debug tooling — not for end users |
| Removed "Onboarding Status" | Internal state — not user-facing |
| App version reads from bundle | Was hardcoded as `1.0`; now displays `MARKETING_VERSION (BUILD)` from Info.plist (e.g. `3.7 (1)`) |

---

*PRD v3.0 — Supersedes v2.0 "Tribe Command" — May 2026 — Updated June 9, 2026*