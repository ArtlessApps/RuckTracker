# Debugging Guide - Program Workout Tracking

## Overview
Comprehensive debugging has been added to trace the entire workout save and program enrollment flow to identify why duplicate/ghost workouts are appearing.

## Color-Coded Debug Logs

All debug logs are now color-coded with emojis for easy identification:

- 🔵 **BLUE** = `WorkoutDataManager.saveWorkout()` - Core Data save operations
- 🔴 **RED** = `WorkoutDataManager.deleteWorkoutsForProgram()` - Deletion operations
- 🟢 **GREEN** = `LocalProgramStorage.enrollInProgram()` - Enrollment operations
- 🟡 **YELLOW** = `LocalProgramStorage.getProgramProgress()` - Progress calculation
- 🟣 **PURPLE** = `WorkoutManager.saveWorkoutToLocalStorage()` - Workout manager flow
- 🟠 **ORANGE** = `LocalProgramService.refreshProgramProgress()` - Service layer refresh
- 🔍 **MAGNIFYING GLASS** = `WorkoutDataManager.dumpAllWorkouts()` - Full CoreData dump

## Debug Flow

### When Enrolling in a Program:
```
🟢 ===== ENROLLING IN PROGRAM =====
🟢 Program ID: [uuid]
🟢 Starting Weight: [weight] lbs
🟢 About to delete old workouts for this program...
  🔴 ===== DELETING PROGRAM WORKOUTS =====
  🔴 Found [X] workouts to delete for this program
  🔴 Deleting workout 1: Day X, Date: [date]
  🔴 Total workouts AFTER delete: [count]
  🔴 ===== DELETION COMPLETE =====
🟢 Old workouts deleted
🟢 Enrollment data saved to UserDefaults
🟢 ===== ENROLLMENT COMPLETE =====
```

### When Completing a Workout:
```
🟣 ===== WORKOUT MANAGER: SAVING WORKOUT =====
🟣 Enrolled Program ID: [uuid or NONE]
🟣 Program Workout Day: [day or NONE]
🟣 About to call WorkoutDataManager.saveWorkout()...
  🔵 ===== SAVING NEW WORKOUT =====
  🔵 Program ID: [uuid or NONE]
  🔵 Program Workout Day: [day or NONE]
  🔵 Current workout count BEFORE save: [count]
  🔵 Set workout.programId = [uuid]
  🔵 Set workout.programWorkoutDay = [day]
  🔵 Context saved to CoreData
  🔵 Current workout count AFTER save: [count]
  🔵 ===== WORKOUT SAVED =====
🟣 WorkoutDataManager.saveWorkout() completed
🟣 This was a program workout - refreshing progress...
  🟠 ===== REFRESHING PROGRAM PROGRESS =====
  🟠 About to call storage.getProgramProgress()...
    🟡 ===== CALCULATING PROGRAM PROGRESS =====
    🟡 Found [X] completed workouts in CoreData
    🟡 Workouts matching this program: [count]
    🟡   Workout 1: Day X, Date: [date]
    🟡 Total workouts expected: 60
    🟡 Completion percentage: [X]%
    🟡 Next workout day: [X]
    🟡 ===== PROGRESS CALCULATION COMPLETE =====
  🟠 New progress: [X]/[Y] workouts
  🟠 ===== REFRESH COMPLETE =====
🟣 ===== WORKOUT MANAGER: SAVE COMPLETE =====
```

## Key Things to Look For

### 1. Enrollment Issues
- Check if `deleteWorkoutsForProgram()` is deleting the correct number of workouts
- Verify the programId matches between enrollment and deletion
- Confirm "Total workouts AFTER delete" shows the expected count

### 2. Duplicate Saves
- Watch for multiple `🔵 SAVING NEW WORKOUT` blocks for the same workout
- Check if workout count increases by exactly 1 each time
- Verify programId and programWorkoutDay are set correctly

### 3. Progress Calculation Issues
- Verify "Workouts matching this program" count is accurate
- Check if the workout day numbers match what was saved
- Compare "completed workouts" with actual workouts in the list

### 4. Ghost Workouts
- If you see more workouts than expected, use `dumpAllWorkouts()`
- Check if old workouts have the same programId
- Verify deletion is happening before enrollment

## Debugging Commands

### Dump All Workouts in CoreData:
Add this to your view or test code:
```swift
WorkoutDataManager.shared.dumpAllWorkouts()
```

This will print every workout in CoreData with full details.

### Watch Live Logs:
When running in Xcode, filter the console by:
- `🔵` - See all workout saves
- `🔴` - See all deletions
- `🟢` - See all enrollments
- `🟡` - See all progress calculations

## Testing Procedure

1. **Start Fresh**:
   - Note the current workout count
   - Use `dumpAllWorkouts()` to see what's in CoreData

2. **Enroll in Program**:
   - Watch for 🟢 GREEN logs
   - Verify 🔴 RED deletion logs show correct count
   - Check final workout count

3. **Complete First Workout**:
   - Watch for 🟣 PURPLE → 🔵 BLUE → 🟠 ORANGE → 🟡 YELLOW flow
   - Verify workout count increases by exactly 1
   - Check programWorkoutDay = 1

4. **Complete Additional Workouts**:
   - Each completion should increase count by 1
   - programWorkoutDay should increment sequentially
   - "Workouts matching this program" should match completed count

5. **Re-enroll in Same Program**:
   - 🟢 Enrollment should trigger 🔴 deletion
   - All previous workouts for this program should be deleted
   - Starting fresh with workout count = 0 for this program

## What We're Looking For

The goal is to identify:
1. **Where** are the extra workouts coming from?
2. **When** are they being created?
3. **Why** aren't they being deleted on re-enrollment?

The detailed logs will show us the exact sequence of operations and help pinpoint the issue.

