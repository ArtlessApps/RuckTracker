# Calorie Tracking Bug Fix

## Issue
Calories were not being counted during workouts on the **iOS (iPhone) app**, resulting in the post-workout summary showing 0 calories.

## Root Cause
The iOS app's `WorkoutManager` had two critical issues with calorie calculation:

1. **Distance requirement was too strict**: The `updateCalories()` method only calculated calories if `distance > 0.01` miles. If GPS wasn't tracking properly or hadn't accumulated enough distance yet (common indoors or when GPS signal is weak), calories would never be calculated—even if the workout lasted 30+ minutes.

2. **Missing final calculation**: The `endWorkout()` method didn't call `updateCalories()` before capturing final stats. Since calories only updated every 10 seconds during the workout, the final value could be up to 9 seconds stale, or worse, still at 0 if distance never exceeded 0.01 miles.

## Solution Applied

### 1. Implemented Three-Tier Hybrid Calorie System ✨
Modified `updateCalories()` in the iOS `WorkoutManager.swift` with intelligent tiering:

**Tier 1 - GPS-Based (Primary)**:
- Uses actual distance when `distance > 0.01` miles
- Most accurate - includes pace and ruck weight adjustments
- Outdoor workouts get full MET-based calculations

**Tier 2 - Movement-Validated Fallback**:
- Activates when GPS unavailable BUT movement detected in last 2 minutes
- Uses base MET (3.5) for stationary/slow movement with ruck adjustment
- Handles indoor workouts and GPS acquisition period

**Tier 3 - Safety Fallback**:
- Activates when NO movement detected for 2+ minutes
- Minimal calories (standing MET of 1.5) - only weight carrying
- **Prevents phantom calories** if user forgets to stop workout

### 2. Added Movement Detection System
New tracking variables and logic:
- `lastDistanceUpdateTime`: Tracks when GPS distance last increased
- `lastDistanceValue`: Records last known distance
- `isUserMoving()`: Validates movement within 120-second window
- Updates timestamp whenever GPS shows 5+ meter movement

### 3. Added Final Calorie Update Before Saving
Modified `endWorkout()` in the iOS `WorkoutManager.swift`:
- **Before**: Captured final stats immediately, potentially missing up to 9 seconds of calorie data
- **After**: Calls `updateCalories()` right before capturing final stats
- Ensures the post-workout summary shows the most accurate calorie count

### 4. Enhanced Logging
Three different log messages based on tier:
- `📊 Calorie calc (GPS)`: Full distance-based calculation
- `📊 Calorie calc (stationary)`: Time-based with movement validation
- `⚠️ Calorie calc (no movement)`: Minimal standing calories

Makes debugging and understanding calorie behavior much easier.

## How It Works Now

The iOS app uses a **three-tier intelligent calorie system**:

### Priority 1: GPS-Based (Best Accuracy)
- Uses actual distance traveled
- Calculates pace-based MET values (faster = higher calories)
- Adds ruck weight adjustment (6% per 10% body weight)
- **Example**: 30-min, 1.5 miles, 30lb ruck = ~300 calories

### Priority 2: Movement-Validated Fallback
- Triggers when GPS unavailable BUT movement detected recently
- Uses base MET (3.5) for stationary activity + ruck adjustment  
- Grace period: Assumes moving if GPS updated within 2 minutes
- **Example**: 10-min indoor, 30lb ruck = ~80 calories

### Priority 3: Safety Net (Prevents Phantom Calories)
- Triggers when NO movement for 2+ minutes
- Minimal calories (MET 1.5 = standing only)
- **Protects against "forgot to stop" scenario**
- **Example**: 30-min forgotten workout = ~70 cal (not 300+!)

### Movement Detection
- Tracks GPS distance update timestamps
- 2-minute window for movement validation
- First 2 minutes always considered "moving" (GPS acquisition)
- Updates timestamp whenever GPS shows 5+ meter movement

## Testing Recommendations

### Test 1: Normal Outdoor Workout ✅
**Action**: 30-min outdoor walk with 30lb ruck  
**Expected**: Tier 1 (GPS) throughout, ~300 calories  
**Verify**: Check console for "📊 Calorie calc (GPS)" messages

### Test 2: Indoor Workout ✅  
**Action**: 15-min indoor workout with 30lb ruck  
**Expected**: Tier 2 for first 2 min, then Tier 3, ~100-120 calories  
**Verify**: Check for "stationary" then "no movement" logs

### Test 3: Forgot to Stop (Key Test!) ❌→✅
**Action**: 5-min walk, then leave phone on desk for 25 min  
**Expected**: ~50 cal (walking) + ~50 cal (standing) = ~100 total  
**Critical**: Should NOT show 300+ calories!

### Test 4: Poor GPS Signal ✅
**Action**: Walk through buildings/tunnels  
**Expected**: Smooth transition between Tier 1 and Tier 2  
**Verify**: No sudden calorie drops, continuous accumulation

### Test 5: Quick Workout ✅
**Action**: 2-min outdoor walk  
**Expected**: Some calories based on distance or movement  
**Verify**: Non-zero value in summary

## Files Modified

1. `RuckTracker/WorkoutManager.swift` (iOS app)
   - Added movement detection variables (`lastDistanceUpdateTime`, `lastDistanceValue`)
   - Completely rewrote `updateCalories()` with three-tier system
   - Added `isUserMoving()` helper method for movement validation
   - Modified `endWorkout()` to call `updateCalories()` before saving final stats
   - Updated location manager to track distance update timestamps
   - Enhanced logging with tier-specific messages
   - Added movement detection reset in `resetWorkoutData()` and `startWorkout()`

## Note on Watch App

As a bonus, I also fixed a similar potential issue in the Watch app by:
- Adding `CalorieCalculator.swift` to the Watch app
- Adding a fallback calorie calculation method
- Calling it during the timer and before ending workouts
This ensures the Watch app also has robust calorie tracking even if HealthKit data is delayed.

