# Future Features

Planned features that are **not yet implemented**. These are listed in the `PremiumFeature` enum and data models but have no working UI, integration, or premium gate wired up yet.

> **Important:** Do not advertise these in the paywall, onboarding, or any user-facing sales copy until they are fully implemented and tested.

---

## Smart Audio Coaching

**Status:** Deferred past MARCH v3.0 (revenue unlock + HR zones ship first). Skeleton code exists, not integrated.  
**Premium feature key:** `.audioCoaching`  
**File:** `RuckTracker/AudioCoach.swift`

### What exists today
- `AudioCoach` singleton with `AVSpeechSynthesizer`-based text-to-speech
- `speak()`, `announceSplit(mile:pace:)`, and `announceMilestone(distance:)` methods
- `MarchPlanGenerator` session descriptors contain `premiumHook` strings referencing audio coach prompts (e.g. "Audio coach guides HR zones", "Audio coach calls GO / RECOVER")

### What's missing
- [ ] No view or workout tracker calls `AudioCoach.shared` — it's an orphaned singleton
- [ ] No premium gate (`checkAccess(.audioCoaching)`) is called anywhere
- [ ] No user-facing toggle to enable/disable audio coaching
- [ ] No integration with the active workout view (mile splits, pace cues, milestone announcements)
- [ ] The `premiumHook` strings in `MarchPlanGenerator` are informational only — they aren't used to trigger actual audio

### Implementation notes
- Wire `AudioCoach.announceSplit()` into the workout tracker's distance/mile callback
- Wire `AudioCoach.announceMilestone()` into distance thresholds (6mi, 12mi)
- Add a settings toggle for audio coaching (respecting `isEnabled`)
- Gate behind `PremiumFeature.audioCoaching`

---

## Heart Rate Zones

**Status:** Shipped on iPhone (v3.0) — active workout zone chip + post-workout time-in-zone summary for Pro users  
**Premium feature key:** `.heartRateZones`  
**Files:** `RuckTracker/HeartRateZoneCalculator.swift`, `RuckTracker/WorkoutManager.swift`, `RuckTracker/ActiveWorkoutFullScreenView.swift`, `RuckTracker/PhonePostWorkoutSummaryView.swift`

### What exists today
- `HeartRateZone` enum with 5 zones: Recovery, Aerobic, Threshold, Anaerobic, Neuromuscular
- iPhone: real-time zone display during workout, time-in-zone on post-workout summary (Pro)
- Watch app computes a `heartRateZone` string from current heart rate for HealthKit metadata tagging

### What's still missing
- [ ] Zone-based coaching or alerts ("You're in Zone 4, slow down")
- [ ] Persist time-in-zone to Core Data workout records
- [ ] Personalize zone thresholds based on user age or max HR setting
- [ ] Audio coaching integration (deferred)

---

## Interval Timers

**Status:** Enum case only, no implementation  
**Premium feature key:** `.intervalTimers`

### What exists today
- `PremiumFeature.intervalTimers` case with display name, description, icon, and category
- That's it — no code, no UI, no model

### What's missing
- [ ] No `IntervalTimer` class or model
- [ ] No interval timer UI (work/rest configuration, countdown display)
- [ ] No integration with workout tracking (auto-pause between intervals, segment recording)
- [ ] No premium gate (`checkAccess(.intervalTimers)`) is called anywhere
- [ ] No audio cues for interval transitions (would pair with Audio Coaching)

### Implementation notes
- Design an interval model: work duration, rest duration, rounds, optional weight changes
- Build countdown UI overlay for active workout view
- Pair with `AudioCoach` for "GO" / "REST" voice prompts
- Consider integration with `WorkoutSegment` from `WorkflowModels.swift`
- Gate behind `PremiumFeature.intervalTimers`

---

## Tracking

| Feature | Enum exists | Code exists | UI exists | Gate wired | Shipped |
|---------|:-----------:|:-----------:|:---------:|:----------:|:-------:|
| Audio Coaching | ✅ | Partial | ❌ | ❌ | ❌ |
| Heart Rate Zones | ✅ | Partial | ✅ | ✅ | ✅ (iPhone) |
| Interval Timers | ✅ | ❌ | ❌ | ❌ | ❌ |
