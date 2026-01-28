Here is the comprehensive monetization strategy for **MARCHv2.0**.

This strategy is built on the **"Trojan Horse"** model: We use the **Free Tier** to displace Facebook Groups (solving the "Empty Room" problem) and the **Pro Tier** to monetize the users who want to get serious about their performance.

### 1. The Core Philosophy

* **The "Club OS" (Free):** Everything a user needs to **show up** and **participate** in a group is free. This ensures zero friction for Club Leaders inviting their members.
* **The "Digital Coach" (Pro):** Everything a user needs to **get better** (structured training, audio cues, advanced data) is paid.

---

### 2. Tier Breakdown: Standard vs. Pro

Feature Category,"Standard (Free)""The Club Member""","Pro ($4.99/mo)""The Ruck Athlete"""
🛡️ Club Tools,"Unlimited (Critical)Join Clubs, Sign Waivers, RSVP to Events, View Event Maps, Group Chat.",UnlimitedSame access. (We never gate the social utility).
🧠 Training Plans,"Locked 🔒Can view the list of plans, but cannot start them.","Unlimited AccessFull access to the Dynamic Plan Generator and all 10+ Static Programs (Selection Prep, etc)."
🏃‍♂️ Tracking,"""Open Ruck"" OnlyBasic GPS recording (Time, Distance, Pace).","Smart CoachingAudio Cues (""Speed up"", ""Halfway""), Heart Rate Zones, Interval Timers."
📊 Analytics,Session SummaryBasic map and stats for today's workout.,"""Heavy Hauler"" DataTonnage Trends, Vertical Gain Analysis, Progress Charts over time."
🏆 Competition,Local OnlyView Club Leaderboards only.,"Global ArenaAccess Global Leaderboards. Rank against the world. Unlock ""Pro Badges."""
📸 Social Sharing,Standard CardBasic image with logo.,"""Propaganda"" ModeMassive ""Tonnage"" overlay, Club Name Badge, 'Military Stencil' visual theme."

---

### 3. The "Gate" Experience (UX Flow)

This is the critical conversion point. We let the user *build* the plan (investment), but we gate the *execution* (reward).

**Context:** The user is in `PhoneOnboardingView`. They have answered the questions (Goal, Experience, Days/Week).

**Step 1: The Magic Moment (The Hook)**

* **Screen:** `PlanGenerationView`
* **Visual:** "Building your 8-Week Selection Plan..." (Progress bar).
* **Result:** A beautiful Calendar View appears, populated with specific workouts (e.g., "Tue: 4mi Interval", "Sat: 10mi Heavy").
* **Psychology:** The user feels ownership. "This is *my* plan."

**Step 2: The Action**

* **User Action:** User taps the **"Start Workout 1"** button on the bottom of the screen.

**Step 3: The Gate (The Paywall)**

* **Modal Appears:** `SubscriptionPaywallView`
* **Headline:** "Unlock your Custom Plan."
* **Subtext:** "Train effectively with audio coaching, progress tracking, and smart targets."
* **Price:** **"$4.99 / Month"** (Primary Button) or "$39.99 / Year" (Secondary).

**Step 4: The Decision**

* **Path A: "Subscribe"**
* Payment processes via StoreKit.
* The modal dismisses.
* The "Workout Player" immediately launches for Workout 1. **(Instant Gratification)**.


* **Path B: "Maybe Later" (The Down-sell)**
* User taps small text "Maybe Later" or "Use Free Version."
* **The Redirect:** The Calendar/Plan view **disappears**.
* User is routed to `PhoneMainView` (The Dashboard).
* **The State:** They *cannot* access the "Coach" tab anymore. They can only see the "Tribe" (Feed) and a big "Go Ruck" button (Basic Tracking).
* **Why:** We don't want them to feel "stuck" on a locked screen. We drop them into the *Free Utility* so they can still RSVP to their club events (retaining them as a DAU).



---

### 4. The "Ambassador" Override (Growth Strategy)

To solve the "Empty Room" problem, we bypass the gate for specific users.

**The Logic:**
If a user is a **Club Founder** with active members, the Paywall in Step 3 **does not appear.**

**Implementation in `PremiumManager.swift`:**

```swift
func checkPremiumStatus() async {
    // 1. Check Apple Subscription
    if await StoreKitManager.shared.hasActiveSubscription {
        self.isPremium = true
        return
    }
    
    // 2. Check "Ambassador" Grant (The Growth Hack)
    // If they own a club with >5 members, they get Pro for free.
    let ownedClubs = await CommunityService.fetchOwnedClubs(userId: currentUser.id)
    if ownedClubs.filter({ $0.memberCount >= 5 }).count > 0 {
        self.isPremium = true
        self.isAmbassador = true // Show a special badge?
    }
}

```

**The Marketing Pitch to Leaders:**

> "Bring your club to RuckTracker for the RSVPs and Waivers. If you do, I'll give **you** the $60/year Training Plan subscription for free."

### 5. Technical Next Steps (For Cursor)

1. **Modify `PhoneOnboardingView.swift`:** Ensure the "Plan Generation" flow happens *before* the account creation is finalized, so the "Start Workout" button is the very last step.
2. **Update `SubscriptionPaywallView.swift`:** Add the "Maybe Later" button that triggers a navigation root change to `PhoneMainView`.
3. **Update `PlanView.swift`:** Wrap the "Start Workout" action in a `if !PremiumManager.isPremium { showPaywall = true }` check.
4. **Implement `PremiumManager` Logic:** Add the Ambassador check to Supabase.