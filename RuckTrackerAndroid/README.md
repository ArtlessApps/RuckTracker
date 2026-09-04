# MARCH Android

Native Android port of the MARCH iOS rucking app. Shares the same Supabase backend.

## Open in Android Studio

Open the `RuckTrackerAndroid/` directory. Sync Gradle, then run on a device or emulator (API 26+).

**New to Android?** Start with [SETUP.md](SETUP.md).

## Testing & release docs

| Doc | Purpose |
|-----|---------|
| [SETUP.md](SETUP.md) | First-time Android Studio + device setup |
| [QA_CHECKLIST.md](QA_CHECKLIST.md) | Printable manual test checklist |
| [BILLING_TEST_SETUP.md](BILLING_TEST_SETUP.md) | Play Console subscription testing |
| [PLAYSTORE.md](PLAYSTORE.md) | Production submission checklist |

## Build from CLI

```bash
./gradlew assembleDebug    # debug APK
./gradlew bundleRelease    # release AAB for Play Store
```

## Architecture

- **UI**: Jetpack Compose, 5-tab navigation (Ruck, Plan, Tribe, Rankings, You)
- **DI**: Hilt
- **Local storage**: Room (workouts + route points)
- **Backend**: Supabase (auth, clubs, events, feed, leaderboards)
- **Billing**: Google Play Billing Library 7
- **Health**: Health Connect (heart rate)
- **Location**: Fused Location Provider + foreground service

## Feature parity with iOS

| Feature | Status |
|---------|--------|
| Email auth | Done |
| 12-step onboarding | Done |
| Google Play subscriptions | Done |
| GPS workout tracking | Done |
| Post-workout summary + share cards | Done |
| 5-tab navigation | Done |
| Plan generation | Done |
| Training programs (8) | Done |
| Weekly challenges (8) | Done |
| Clubs (join/create/feed/leaderboard) | Done |
| Events + RSVPs | Done |
| Global leaderboards (4 metrics) | Done |
| Analytics + settings | Done |
| CSV export | Done |
| Deep links (`rucktracker://`) | Done |
| Ambassador premium | Done |
| Wear OS | Out of scope |
