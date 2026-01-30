# MARCH Community Features - Implementation Guide

## Overview
This guide walks you through adding Runna-style community features to MARCH using Supabase. You'll get:
- User accounts & profiles
- Clubs (virtual communities)
- Activity feeds (auto-posted workouts)
- Weekly leaderboards
- Social interactions (likes)

**Total Implementation Time: 4-6 hours** (including Supabase setup)

---

## STEP 1: Supabase Setup (30 minutes)

### 1.1 Create Supabase Project

1. Go to https://supabase.com
2. Click "Start your project"
3. Create new project:
   - Name: "MARCH Community"
   - Database Password: (generate strong password, save it!)
   - Region: Choose closest to your users
   - Plan: Free tier is fine to start

### 1.2 Run the SQL Schema

1. In Supabase dashboard, go to "SQL Editor"
2. Click "New Query"
3. Copy entire contents of `supabase_community_schema.sql`
4. Paste into query editor
5. Click "Run" (bottom right)
6. Wait ~10 seconds for all tables to be created
7. Verify: Go to "Table Editor" - you should see 6 tables:
   - profiles
   - clubs
   - club_members
   - club_posts
   - post_likes
   - leaderboard_entries

### 1.3 Get Your API Keys

1. In Supabase dashboard, go to "Settings" → "API"
2. Copy two values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: Long string starting with `eyJ...`
3. Save these - you'll need them in Step 2

### 1.4 Enable Email Auth

1. Go to "Authentication" → "Providers"
2. Make sure "Email" is enabled (should be default)
3. That's it! Email/password auth is ready

---

## STEP 2: Add Supabase to Your Xcode Project (20 minutes)

### 2.1 Install Supabase Swift Package

1. Open your MARCH project in Xcode
2. Go to File → Add Package Dependencies
3. Enter URL: `https://github.com/supabase/supabase-swift`
4. Version: "Latest" (currently 2.x)
5. Click "Add Package"
6. Select these products:
   - ✅ Supabase
   - ✅ Auth
   - ✅ PostgREST
   - ✅ Realtime (optional, for future features)
7. Click "Add Package"

### 2.2 Add Your Supabase Credentials

1. Open `CommunityService.swift` (the file I created)
2. Find line ~30:
   ```swift
   private let supabase = SupabaseClient(
       supabaseURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
       supabaseKey: "YOUR_ANON_KEY"
   )
   ```
3. Replace with YOUR actual values from Step 1.3
4. Save the file

---

## STEP 3: Add the Code Files to Your Project (15 minutes)

### 3.1 Add CommunityService.swift

1. In Xcode, right-click on your project folder (where other .swift files are)
2. Click "Add Files to MARCH..."
3. Select `CommunityService.swift`
4. Make sure "Copy items if needed" is checked
5. Click "Add"

**What this file does:**
- Handles all communication with Supabase
- Sign up, sign in, sign out
- Create clubs, join clubs
- Post workouts to feeds
- Load leaderboards

### 3.2 Add CommunityTribeView.swift

1. Same process: Add Files → `CommunityTribeView.swift`
2. This is your new TRIBE tab UI

**What this file contains:**
- Main TRIBE tab view
- Club list
- Club detail (feed + leaderboard)
- Join/create club flows
- Authentication screens

### 3.3 Add WorkoutCommunityIntegration.swift

1. Add Files → `WorkoutCommunityIntegration.swift`
2. This connects workouts to community features

**What this does:**
- Auto-posts workouts to clubs after completion
- Includes optional share sheet

---

## STEP 4: Replace Your TRIBE Tab (10 minutes)

### 4.1 Update MainTabView.swift

1. Open `MainTabView.swift`
2. Find this section (around line 30):
   ```swift
   ChallengesView(isPresentingWorkoutFlow: .constant(false))
   .tabItem {
       Label("Tribe", systemImage: "person.3.fill")
   }
   .tag(2)
   ```

3. Replace with:
   ```swift
   CommunityTribeView()
   .tabItem {
       Label("Tribe", systemImage: "person.3.fill")
   }
   .tag(2)
   ```

4. Save the file

**What this does:**
- Swaps out the old challenges-only view
- Replaces with new community-focused view
- Keeps the same tab icon and position

---

## STEP 5: Connect Workouts to Community (30 minutes)

### 5.1 Find Your Workout Save Logic

1. Open `WorkoutManager.swift`
2. Find the method where you save completed workouts to CoreData
3. It's probably called something like:
   - `saveWorkout()`
   - `endWorkout()`
   - `completeWorkout()`

### 5.2 Add Auto-Posting

After the workout is saved to CoreData, add this code:

```swift
// Auto-share to community clubs
Task {
    await shareWorkoutToClubs(
        workoutId: savedWorkout.id!, // Your workout UUID
        distance: finalDistance,
        duration: Int(finalElapsedTime / 60), // Convert seconds to minutes
        weight: finalRuckWeight,
        calories: finalCalories
    )
}
```

**Example of where to add it:**

```swift
func endWorkout() async {
    // ... your existing logic ...
    
    // Save to CoreData
    workoutDataManager.saveWorkout(
        distance: finalDistance,
        duration: finalElapsedTime,
        weight: finalRuckWeight,
        calories: finalCalories
    )
    
    // NEW: Auto-share to clubs
    if let workoutId = workoutDataManager.lastSavedWorkoutId {
        Task {
            await shareWorkoutToClubs(
                workoutId: workoutId,
                distance: finalDistance,
                duration: Int(finalElapsedTime / 60),
                weight: finalRuckWeight,
                calories: finalCalories
            )
        }
    }
    
    // ... rest of your logic ...
}
```

### 5.3 Test It

1. Build and run the app
2. Complete a workout
3. Check Supabase dashboard → Table Editor → club_posts
4. You should see a new row with your workout data!

---

## STEP 6: Test the Full Flow (1 hour)

### 6.1 Create Test Account

1. Run the app
2. Tap TRIBE tab
3. Tap "Sign In or Create Account"
4. Fill in:
   - Email: your-email@test.com
   - Password: TestPass123!
   - Username: testrucker
   - Display Name: Test Rucker
5. Tap "Create Account"

### 6.2 Create a Club

1. After sign in, tap "Create a Club"
2. Fill in:
   - Name: "Test Ruck Club"
   - Description: "Testing community features"
3. Tap "Create Club"
4. You'll see a club card appear

### 6.3 Join a Club (Test with Friend)

1. In Supabase dashboard, go to Table Editor → clubs
2. Find your club row
3. Copy the `join_code` value (e.g., "TES-1234")
4. Have a friend (or use a second device):
   - Install the app
   - Create account
   - Tap "Join a Club"
   - Enter the code
   - They're now in your club!

### 6.4 Post a Workout

1. Complete a real workout OR use test data
2. After workout saves, it auto-posts to your clubs
3. Go to TRIBE tab → tap your club
4. You should see your workout in the feed!

### 6.5 Check Leaderboard

1. In club detail, switch to "Leaderboard" tab
2. You should see yourself ranked #1
3. Have friend complete workout
4. Refresh - you'll see both of you ranked by distance

---

## STEP 7: Premium Gating (Optional, 30 minutes)

If you want to make community features premium-only:

### 7.1 Add Premium Check

In `CommunityTribeView.swift`, add this at the top of the body:

```swift
var body: some View {
    Group {
        if !PremiumManager.shared.isPremiumUser {
            // Show paywall
            VStack(spacing: 24) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.primary)
                
                Text("Premium Feature")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Join the MARCH community, compete on leaderboards, and share your workouts.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Upgrade to Premium") {
                    PremiumManager.shared.showPaywall(context: .communityAccess)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
            }
        } else {
            // Show normal community view
            NavigationView {
                // ... rest of your existing code
            }
        }
    }
}
```

### 7.2 Update Premium Features List

In `PremiumManager.swift`, add to the `PremiumFeature` enum:

```swift
case community

var displayName: String {
    switch self {
    case .community:
        return "Community & Clubs"
    // ... other cases
    }
}

var description: String {
    switch self {
    case .community:
        return "Join clubs, share workouts, compete on leaderboards"
    // ... other cases
    }
}
```

---

## STEP 8: Deploy & Launch Strategy (Ongoing)

### 8.1 Seed Your First Clubs

Before public launch, create 3-5 clubs:
1. "San Diego Ruckers" (your location)
2. "GORUCK Training"
3. "Beginner Ruck Club"
4. "Women Who Ruck"

Why? New users will see active clubs to join immediately.

### 8.2 Reach Out to Local Clubs

Use this template:

> Subject: Free club platform for [Club Name]
>
> Hey [Admin Name],
>
> I built MARCH - a dedicated ruck tracking app - and just launched a clubs feature. I'd love to set up a free club for [Club Name] where your members can:
>
> • Track rucks with accurate calorie calculations
> • Share workouts in a private feed
> • Compete on weekly distance leaderboards
>
> No cost, just looking for feedback. Interested?
>
> Code to join: [YOUR-CODE]
>
> Best,
> Nick

### 8.3 Monitor Growth

Watch these metrics in Supabase:
1. Table Editor → profiles: Total users
2. Table Editor → clubs: Active clubs
3. Table Editor → club_posts: Weekly activity

Aim for:
- Week 1: 3-5 clubs, 50 users
- Month 1: 10-15 clubs, 200 users
- Month 3: 30+ clubs, 500+ users

---

## Troubleshooting

### "User not authenticated" errors
**Fix:** Make sure user signed in before trying to create/join clubs

### Workouts not appearing in feed
**Fix:** Check that `shareWorkoutToClubs()` is being called after workout save

### Can't see clubs after joining
**Fix:** Call `await communityService.loadMyClubs()` after joining

### Supabase RLS errors
**Fix:** Make sure you ran the entire SQL schema (Step 1.2)

### Leaderboard showing no data
**Fix:** Verify `update_leaderboard_entry()` function exists in Supabase

---

## What You Get

After following this guide, MARCH will have:

✅ User accounts (email/password)
✅ User profiles with stats
✅ Clubs (create & join with codes)
✅ Auto-posted workout feed
✅ Weekly distance leaderboards
✅ Social interactions (likes)
✅ Club admin system (future: moderation)

**Just like Runna, but built in-house on Supabase!**

---

## Next Steps (Future Features)

Once core is working, consider adding:

1. **Comments on posts** (add `club_comments` table)
2. **Photo uploads** (Supabase Storage)
3. **Push notifications** (when workout is liked, etc.)
4. **Monthly challenges** (special time-boxed competitions)
5. **Badges/achievements** (first workout, 100 miles, etc.)
6. **Friends system** (follow specific users)
7. **Direct messages** (1-on-1 chat)

---

## Cost Estimates

**Supabase Pricing:**
- Free tier: Up to 500MB database, 50,000 monthly active users
- Pro tier: $25/month (starts at 8GB database, 100,000 MAUs)

**Expected costs:**
- 0-100 users: Free
- 100-1,000 users: Free
- 1,000-5,000 users: $25/month
- 5,000+ users: $25-100/month

**Way cheaper than Bettermode's $799-999/month!**

---

## Support

If you get stuck:
1. Check Supabase docs: https://supabase.com/docs
2. Check Supabase Discord: https://discord.supabase.com
3. Search issues on supabase-swift GitHub

Good luck! 🚀