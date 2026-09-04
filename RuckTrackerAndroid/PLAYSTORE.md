# MARCH Android — Play Store Submission Checklist

## Pre-submission

- [ ] Create Google Play Console app listing for `com.artless.rucktracker`
- [ ] Generate upload keystore and configure signing in Android Studio
- [ ] Add privacy policy URL (reuse iOS policy at artless.app)
- [ ] Complete Data Safety form (location, health data, account info)
- [ ] Configure Play Billing products:
  - `com.artless.rucktracker.premium.monthly` ($4.99/mo)
  - `com.artless.rucktracker.premium.yearly` ($39.99/yr)
- [ ] Add license testers for billing QA

## Store listing

- **Title**: MARCH — Ruck Tracker & Clubs
- **Short description**: Track rucks, join tribes, climb leaderboards.
- **Full description**: Reuse ASO copy from `AppStoreOptimizer.md`

## Release tracks

1. Internal testing (team devices)
2. Closed beta (rucking club founders)
3. Production

## Build command

```bash
cd RuckTrackerAndroid
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`
