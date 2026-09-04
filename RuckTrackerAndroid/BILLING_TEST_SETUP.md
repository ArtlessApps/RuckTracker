# MARCH Android — Play Billing Test Setup

Subscriptions won't work until the app is in Play Console with matching product IDs. Follow these steps once before testing the paywall.

## Product IDs (must match exactly)

| Product | ID | Price |
|---------|-----|-------|
| Monthly Pro | `com.artless.rucktracker.premium.monthly` | $4.99/mo |
| Yearly Pro | `com.artless.rucktracker.premium.yearly` | $39.99/yr |

These match iOS StoreKit IDs in `MARCHSubscriptions.storekit`.

---

## Step 1: Create the Play Console app

1. Go to [play.google.com/console](https://play.google.com/console)
2. **Create app** → name: MARCH, default language, app/game type: App
3. Package name: **`com.artless.rucktracker`** (must match `applicationId` in `app/build.gradle.kts`)

You don't need a finished store listing to test billing — internal testing is enough.

---

## Step 2: Upload a build to Internal testing

Play Billing only works with builds installed from Play (or license tester sideload exceptions in some cases). Easiest path:

```bash
cd RuckTrackerAndroid
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

1. Play Console → **Testing → Internal testing**
2. **Create new release** → upload the `.aab`
3. Add yourself as an internal tester (email list)
4. Open the **opt-in link** on your test phone and install from Play Store

For debug builds during early dev, you can still test paywall UI — purchases will fail until Play products exist.

---

## Step 3: Create subscription products

1. Play Console → **Monetize → Products → Subscriptions**
2. Create subscription: **`com.artless.rucktracker.premium.monthly`**
   - Base plan: monthly, $4.99
   - Optional: free trial (match iOS 7-day trial if desired)
3. Create subscription: **`com.artless.rucktracker.premium.yearly`**
   - Base plan: yearly, $39.99

Product IDs must match `BillingManager.kt` constants exactly.

---

## Step 4: Add license testers

1. Play Console → **Settings → License testing**
2. Add your Gmail addresses (the account on your test phone)
3. Set **License response** to `RESPOND_NORMALLY` for realistic purchase flow

License testers can complete purchases without being charged.

---

## Step 5: Verify in the app

1. Install the internal testing build from Play
2. Sign in (or stay anonymous — billing works either way)
3. Tap **Start a Ruck** without Pro → paywall appears
4. Complete a test purchase
5. Confirm:
   - Workout start is unlocked
   - If signed in: `user_subscriptions` row appears in Supabase
   - `profiles.is_premium` updates to true

---

## Ambassador path (no purchase needed)

Club founders with **5+ active members** get free Pro — same as iOS. Test with a founder account that already qualifies on iOS; Android should pick up ambassador status after sign-in.

---

## Google Sign-In (optional, not required for billing)

If you want Google auth (Android equivalent of Sign in with Apple):

1. Play Console → **Setup → App integrity** → copy **SHA-1** fingerprint
2. Google Cloud Console → create OAuth Android client with package `com.artless.rucktracker` + SHA-1
3. Supabase Dashboard → Authentication → Google provider → add client ID
4. Redirect URI: `com.artless.rucktracker://login-callback` (see `GoogleSignInHelper.kt`)

Email/password auth works without this setup.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Item not found" on purchase | Product IDs don't match, or app not installed from Play internal track |
| Paywall shows but purchase hangs | Wait for Play products to propagate (can take a few hours after creation) |
| Purchase succeeds but still locked | Sign in so subscription syncs to `user_subscriptions`; call refresh after purchase |
| Billing works on iOS but not Android | Separate stores — Android needs Play Console products, not App Store Connect |
