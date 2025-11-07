# Calorie Calculation Strategy

## Overview
This document explains the **hybrid, movement-validated calorie calculation** system used in RuckTracker, designed to be accurate while preventing false calorie accumulation if users forget to stop their workout.

## The Problem We're Solving

1. **GPS-only approach**: Fails indoors or with poor signal → 0 calories even after 30-minute workout ❌
2. **Time-only approach**: Works indoors BUT accumulates calories if user forgets to stop → 1000+ phantom calories ❌
3. **Best-in-class solution**: Hybrid approach with movement detection ✅

## Our Solution: Three-Tier Calorie Calculation

### Tier 1: GPS-Based (Primary - Most Accurate)
**When**: Distance > 0.01 miles (GPS is working)

**Calculation**: Full MET-based with pace and ruck weight
- Uses actual distance traveled
- Calculates pace-based MET values
- Adds load-based MET for ruck weight
- **Most accurate** for outdoor workouts

```swift
calories = CalorieCalculator.calculateRuckingCalories(
    bodyWeightKg: bodyWeight,
    ruckWeightPounds: ruckWeight,
    timeMinutes: elapsed,
    distanceMiles: actualDistance  // Real GPS data
)
```

**Example**: 30-min workout, 1.5 miles, 30lb ruck = ~300 calories

---

### Tier 2: Stationary with Recent Movement (Fallback)
**When**: Distance = 0 BUT movement detected in last 2 minutes

**Calculation**: Base MET for stationary/slow movement
- Uses time only (distance = 0)
- Applies base MET of 3.5 (standing/slow walking)
- Adds ruck weight adjustment
- Prevents 0 calories during GPS acquisition or indoor workouts

```swift
calories = CalorieCalculator.calculateRuckingCalories(
    bodyWeightKg: bodyWeight,
    ruckWeightPounds: ruckWeight,
    timeMinutes: elapsed,
    distanceMiles: 0.0  // Base MET calculation
)
```

**Example**: 10-min indoor workout, 30lb ruck = ~80 calories

**Movement Detection Logic**:
- Tracks timestamp of last GPS distance update
- If update within 120 seconds → user is moving
- If < 120 seconds elapsed → assume moving (GPS acquisition period)

---

### Tier 3: No Movement Detected (Safety Fallback)
**When**: No distance AND no movement detected for 2+ minutes

**Calculation**: Minimal "standing" calories only
- Extremely low MET (1.5 = standing still)
- Only accounts for carrying load weight
- **Prevents phantom calories** if user forgets to stop

```swift
let standingCaloriesPerMinute = bodyWeightKg * 1.5 / 60.0
calories = standingCaloriesPerMinute * (elapsedTime / 60.0)
```

**Example**: 30-min forgotten workout, 30lb ruck = ~70 calories (vs 300+ without protection)

---

## Movement Detection Algorithm

### How We Detect Movement:
1. **GPS Distance Updates**: Track when `distance` value changes
2. **Update Timestamp**: Record time of last distance increase
3. **2-Minute Window**: Consider moving if updated within 120 seconds
4. **Grace Period**: First 2 minutes always considered "moving" (GPS acquisition)

### Why 2 Minutes?
- Outdoor: GPS updates every 5-10 seconds when moving
- Indoor: Allows brief pauses (tying shoes, water break)
- Safety: Long enough to be forgiving, short enough to prevent abuse

---

## Comparison to Other Apps

### Strava
- Auto-pauses after 30 seconds no movement
- Resumes on movement detection
- Requires explicit pause/resume from user

### Apple Fitness
- Uses accelerometer + GPS
- No auto-pause on Apple Watch (manual only)
- More permissive for indoor workouts

### Garmin
- Auto-pause configurable (15s - 2min)
- Aggressive movement detection
- Can be too sensitive (pauses at traffic lights)

### RuckTracker (Our Approach)
- **No auto-pause** (keeps timer running)
- **Smart calorie gating** (reduces rate, doesn't stop entirely)
- **Movement validation** (2-min window)
- **Best of both worlds**: Tracks full time, but calories reflect reality

---

## Edge Cases Handled

### ✅ Indoor Workout (No GPS)
- First 2 minutes: Tier 2 (stationary MET with ruck adjustment)
- After 2 minutes with no movement: Tier 3 (minimal standing calories)
- **Result**: Fair calorie count for actual indoor work

### ✅ Poor GPS Signal
- Uses last known distance
- 2-minute grace period prevents dropping to Tier 3 too quickly
- **Result**: Smooth transition, no jarring calorie drops

### ✅ Forgot to Stop Workout
- After 2 minutes stationary: Drops to Tier 3 (minimal calories)
- Accumulates ~2-3 cal/min instead of 10-15 cal/min
- **Result**: Prevents 1000+ phantom calories

### ✅ Short Pauses (Water, Rest)
- 2-minute window allows brief stops
- Resumes normal calculation when moving again
- **Result**: Realistic calorie totals

### ✅ GPS Acquisition Period
- First 2 minutes always use Tier 2
- Gives GPS time to lock on
- **Result**: No penalty for GPS startup time

---

## Testing Scenarios

### Test 1: Normal Outdoor Workout ✅
- **Action**: 30-min outdoor walk, 2 miles, 30lb ruck
- **Expected**: Tier 1 throughout, ~300 calories
- **Verification**: Check logs for "GPS" mode

### Test 2: Indoor Workout ✅
- **Action**: 15-min indoor walk, 30lb ruck
- **Expected**: Tier 2 for 2 min, then Tier 3, ~100-120 calories
- **Verification**: Check logs for "stationary" then "no movement"

### Test 3: Forgot to Stop ❌ → ✅
- **Action**: 5-min walk, then leave phone on desk for 25 min
- **Expected**: ~50 cal (walking) + ~50 cal (standing) = ~100 total
- **Verification**: Should NOT show 300+ calories

### Test 4: Poor GPS Signal ✅
- **Action**: Walk through building/tunnels
- **Expected**: Smooth transition between Tier 1 and Tier 2
- **Verification**: No calorie drops, continuous accumulation

---

## Configuration Constants

```swift
// Movement detection
private let MOVEMENT_TIMEOUT_SECONDS: TimeInterval = 120  // 2 minutes
private let GPS_MIN_DISTANCE_MILES: Double = 0.01        // ~50 feet

// Calorie calculation
private let BASE_MET_STATIONARY: Double = 3.5            // Standing/slow walk
private let BASE_MET_STANDING: Double = 1.5              // Just standing
```

These can be tuned based on user feedback.

---

## Future Enhancements

### Phase 2 (Optional):
- **CoreMotion Integration**: Use accelerometer for indoor movement detection
- **Auto-Pause UI**: Visual indicator when in Tier 3 mode
- **User Preference**: Toggle between strict/permissive modes

### Phase 3 (Advanced):
- **Heart Rate Validation**: Cross-reference with HR data
- **Machine Learning**: Learn user's typical rucking patterns
- **Altitude Detection**: Adjust for hills/stairs even without GPS distance

---

## Summary

**Problem**: Need accurate calories in all scenarios without phantom accumulation

**Solution**: 
1. ✅ Use GPS distance when available (most accurate)
2. ✅ Fall back to time-based with movement validation (indoor support)
3. ✅ Drop to minimal rate with no movement (safety net)

**Result**: Best-in-class behavior that works indoors, outdoors, and prevents "forgot to stop" disasters.

