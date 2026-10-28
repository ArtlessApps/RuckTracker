# MARCH 3.9 — Watch Import Release Kit

Uploaded to App Store Connect 2026-10-16 as **3.9 (1)**. Use this once the build is approved.

## Before submitting

- [ ] On a real iPhone (TestFlight): record a 1+ mi walk on a Garmin/COROS, let it sync, and test all three notification buttons (**Log Ruck**, **Change Weight**, **Not a Ruck**), including from the lock screen with the app closed
- [ ] While signed in, confirm an imported ruck posts to clubs and the leaderboard
- [ ] If anyone has a recent Garmin, check whether its "Rucking" activity reaches Apple Health as a walk/hike (if not, MARCH won't pick it up)
- [ ] Check onboarding: "Maybe Later" on the paywall led to a "Trial started!" screen in the simulator

## App Store release notes

```
Bring your own watch.

MARCH now imports rucks from Garmin, COROS, Polar, Suunto, and other watches that sync to Apple Health.

• Record your ruck as a walk or hike on your watch
• MARCH asks "Was that a ruck?" — log it in one tap from the notification, with your pack weight pre-filled
• Imported rucks count toward your plan, challenges, leaderboard, and club feed
• Optional auto-log for walks and hikes, so you never have to tap at all
• Manage it under Settings → Other Watches

Thanks to the MARCH community member who asked for this one. Keep the requests coming!
```

## Customer reply (COROS Pace 4 request)

Send once 3.9 is live. Update the first paragraph if it's already out.

> Hi [Name],
>
> Thank you for writing in. Your request got built. The next MARCH update (3.9) works with COROS, Garmin and most other fitness watches. It's with Apple for review now and should be out within a few days.
>
> **How it works with your Pace 4:**
> 1. In the COROS app, connect Apple Health (it's under the third-party app connections) so your workouts sync to it.
> 2. Record your rucks on the watch as a **Walk** or **Hike**.
> 3. After the watch syncs, MARCH will send a notification asking "Was that a ruck?" Tap **Log Ruck** and it's saved with your pack weight. You can change the weight if it was different that day.
>
> Logged rucks count toward your training plan, challenges, the leaderboard and your club feed, the same as rucks tracked in MARCH. If you'd rather not tap anything, turn on **Log Automatically** in Settings → Other Watches.
>
> One limitation: MARCH picks up your rucks once they've synced. It doesn't show live stats from the watch while you're rucking.
>
> If you have a minute after updating, I'd really like to hear how it works with your Pace 4. You're one of the first people to use it with COROS.
>
> Thanks again for the idea,
> Nick

---

# 3.9.1 (1) — Subscription Lockout Fix

Fixes paying subscribers losing Pro while signed in, and Restore Purchases silently doing nothing.

## Before submitting

- [ ] StoreKit config: buy while signed out, then sign in. Pro stays on.
- [ ] Second simulator, same MARCH account, no purchase: Pro comes from the database and survives relaunch.
- [ ] Restore with no subscription shows the "No active MARCH subscription was found…" alert (paywall and onboarding).
- [ ] TestFlight on a real device with a sandbox subscriber: relaunch several times, Pro never drops.

## App Store release notes

```
Fixes an issue where some subscribers were locked out of Pro features while signed in, and where Restore Purchases didn't restore an active subscription. Thanks to everyone who reported it.
```

## Customer reply (subscription lockout, Dickson Weber)

Send once 3.9.1 is submitted for review. It covers the workaround and the fix. Update the second paragraph once 3.9.1 is live.

> Hi Dickson,
>
> I'm sorry about this. You paid for Pro and the app kept locking you out, which shouldn't happen. Thank you for reporting it. Your report let me find the bug.
>
> The problem is on our end, not with your subscription. Your subscription is fine with Apple. When you were signed in, MARCH sometimes failed to match it to your account, and Restore Purchases didn't fix the match. I've fixed both, and the update is with Apple for review now. It should be out in a few days.
>
> **Until then, this should get you back in:**
> 1. Go to Settings in MARCH and sign out.
> 2. Open any Pro feature and tap **Restore Purchases** on the subscription screen.
>
> While you're signed out, MARCH checks your Apple ID's subscription directly, so your Pro features should work. Once the update is installed, sign back in and everything carries over. Your workouts are safe either way.
>
> If that doesn't unlock it, check that you're signed in to the same Apple ID you subscribed with (Settings › your name › Media & Purchases). Then reply here and I'll sort it out with you directly.
>
> Sorry again for the hassle, and thanks for sticking with MARCH.
>
> Nick
