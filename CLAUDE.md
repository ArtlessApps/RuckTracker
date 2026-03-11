# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MARCH** (bundle: `com.artless.rucktracker`) is an iOS fitness app for rucking clubs. It has two targets: the main iPhone app (`RuckTracker`) and an Apple Watch companion app (`RuckTracker Watch App`). There is also a companion Next.js marketing website in `march-website/`.

## Building the iOS App

Build and run exclusively through Xcode — open `RuckTracker.xcodeproj`. There is no command-line build script. Dependencies are managed directly in Xcode (no CocoaPods, no Swift Package Manager manifest file).

- **StoreKit Testing**: Use `MARCHSubscriptions.storekit` (project root) as the StoreKit configuration file in the scheme to test subscriptions without real purchases.
- **Minimum iOS**: 15+
- **No automated tests** exist; testing is manual on-device or in the simulator.

## Website (march-website/)

Next.js 15 + React 19 + TypeScript + Tailwind CSS project.

```bash
cd march-website
npm run dev      # local dev server
npm run build    # production build
npm run lint     # ESLint
```

## Architecture

### App Entry & Navigation

- `RuckTrackerApp.swift` — App entry point, initializes singletons on launch
- `ContentView.swift` — Root: drives Splash → Onboarding → Main flow based on auth state
- `MainTabView.swift` — 5-tab bottom navigation (Home, Plan, Community, Leaderboard, Settings)

### Singleton Managers

Core business logic lives in singleton classes accessed via `.shared`:

| Manager | Responsibility |
|---|---|
| `CommunityService` | All Supabase operations (profiles, clubs, events, feed, leaderboards) |
| `WorkoutManager` | Active workout session via `HKWorkoutSession` |
| `WorkoutDataManager` | Persistent local workout storage (Core Data) |
| `HealthManager` | HealthKit permissions and data queries |
| `StoreKitManager` | StoreKit 2 in-app purchase flow |
| `PremiumManager` | Subscription status; ambassador logic (5+ club members = free Premium) |
| `WatchConnectivityManager` | iPhone ↔ Watch sync via `WCSession` |
| `ChallengeManager` | Challenge enrollment and completion tracking |

### Data Persistence

- **Core Data**: Two separate models — `RuckTracker.xcdatamodel` (iPhone) and `RuckTracker Watch App.xcdatamodel` (Watch) — for workouts, challenges, and program progress.
- **Supabase (PostgreSQL)**: All cloud data — user profiles, clubs, events, RSVPs, posts, leaderboards, subscriptions. The Supabase URL and anon key are hardcoded in `CommunityService.swift`.
- **UserDefaults/AppStorage**: Per-user preferences via `UserSettings.shared`.

### Auth Flow

Supabase email/password auth. On cold launch, `CommunityService.restoreSessionIfNeeded()` reloads the persisted session from Keychain. The deep link scheme `rucktracker://` is registered for OAuth callbacks.

### Key Supabase Tables

`profiles`, `clubs`, `club_members` (roles: founder/leader/member), `club_events`, `event_rsvps`, `club_posts`, `club_post_comments`, `user_subscriptions`, `leaderboards`, `user_badges`

### Premium / Subscriptions

- Products: `com.artless.rucktracker.premium.monthly` ($4.99/mo), `com.artless.rucktracker.premium.yearly` ($39.99/yr)
- `StoreKitManager` handles purchases; `PremiumManager` gates features
- Ambassador path: club founders with 5+ active members get Premium for free

### Watch App

Separate target sharing data via `WatchConnectivityManager`. The Watch app has its own Core Data model and workout session management.

### Models & Services

- `RuckTracker/Models/` — `EventModels.swift` (events, RSVPs, waivers, emergency contacts), `BadgeModel.swift`, `ChallengeModels.swift`, `Program.swift`
- `RuckTracker/Services/` — `CommunityService.swift` (largest file, all Supabase ops), `ShareCardRenderer.swift` (generates shareable workout summary images), `DeepLinkManager.swift`, `EventNotificationService.swift`
- Training programs are defined in local JSON files and loaded by `LocalProgramService`

### UI Patterns

- SwiftUI throughout with `@StateObject`, `@ObservedObject`, and `@EnvironmentObject` for dependency injection
- Combine `@Published` properties drive reactive UI updates
- Several views are very large (e.g., `PhoneOnboardingView.swift`, `CommunityTribeView.swift` are 2000+ lines)
- Debug logging uses emoji-prefixed tags (🏥 HealthKit, 🔑 auth, 🛒 StoreKit, etc.)
