# How to Capture Logs While Walking Away from Xcode

## 🎯 Quick Answer: 3 Options

### Option 1: Mac Console.app + USB Cable (Easiest)
**Best for**: Walking around with long USB cable or staying in WiFi range

1. Connect iPhone to Mac via USB
2. Open **Console.app** (Applications → Utilities → Console)
3. Select your iPhone from sidebar
4. Click "Start" to stream logs
5. In search box, type: `process:RuckTracker` or `🏋`
6. Start workout and walk around
7. Logs appear in real-time on Mac!

**Pros**: ✅ No code changes, real-time viewing  
**Cons**: ⚠️ Limited by USB cable length

---

### Option 2: Mac Console.app + WiFi (Wireless!)
**Best for**: Walking anywhere in your building

**Setup Once:**
1. Connect iPhone via USB
2. Xcode → Window → Devices and Simulators
3. Select iPhone, check ✅ "Connect via network"
4. Wait for WiFi icon, disconnect USB
5. Done! iPhone now debugs wirelessly

**Then for Each Test:**
1. Open Console.app on Mac
2. iPhone shows with WiFi icon
3. Start streaming, filter for RuckTracker
4. Walk anywhere (stay in WiFi range)
5. Logs stream wirelessly! 📡

**Pros**: ✅ Completely wireless, good range  
**Cons**: ⚠️ Must stay on same WiFi network

---

### Option 3: File Logging (I Just Added This!)
**Best for**: Walking outside, long distance tests

**How It Works:**
- I added `DebugLogger.swift` that saves all logs to a text file
- File is saved in iPhone's Documents folder
- View it after your walk!

**Steps:**

1. **Start Workout** (logs automatically save to file)

2. **Walk Around** (as far as you want!)

3. **After Walk, Access Logs:**

   **Method A: Via Xcode**
   ```
   1. Connect iPhone to Mac
   2. Xcode → Window → Devices and Simulators
   3. Select iPhone → Click gear icon → "Download Container..."
   4. Save somewhere
   5. Right-click .xcappdata file → Show Package Contents
   6. Navigate to: AppData/Documents/
   7. Find: RuckTracker_Log_[timestamp].txt
   8. Open in any text editor
   ```

   **Method B: Via Files App** (Easier!)
   ```
   1. On iPhone, open Files app
   2. Browse → On My iPhone → RuckTracker
   3. Look for: RuckTracker_Log_[timestamp].txt
   4. Tap to view or tap share icon to AirDrop to Mac
   ```

   **Method C: Via Finder** (macOS Catalina+)
   ```
   1. Connect iPhone to Mac
   2. Open Finder
   3. Select iPhone from sidebar
   4. Click "Files" tab
   5. Find RuckTracker
   6. Drag RuckTracker_Log_[timestamp].txt to Desktop
   ```

**Pros**: ✅ Unlimited range, captures everything  
**Cons**: ⚠️ View logs after walk (not real-time)

---

## 📝 What Gets Logged

With the file logger, you'll see:

```
[12:34:56.123] ===== RUCK TRACKER DEBUG LOG =====
[12:34:56.124] Started: 2025-11-03 20:34:56 +0000
[12:34:56.125] ===================================

[12:35:10.456] 🏋️‍♀️ ===== STARTING WORKOUT =====
[12:35:10.457] 🏋️‍♀️ Weight: 20.0 lbs
[12:35:10.458] 🏋️‍♀️ Called from: [stack trace]
[12:35:10.459] 🏋️‍♀️ Location authorization status: 4
[12:35:10.460] 🏋️‍♀️ Starting location tracking...
[12:35:10.461] 🏋️‍♀️ ===== WORKOUT START COMPLETE =====

[12:35:15.789] 📍 GPS: First location acquired | Accuracy: 8.5m
[12:35:23.234] 📍 GPS update: +12.5m | Total: 0.008 mi | Accuracy: 7.2m
[12:35:28.567] 📍 GPS update: +15.3m | Total: 0.017 mi | Accuracy: 6.8m
[continues...]
```

**Timestamps** show exact timing of GPS updates!

---

## 🧪 Recommended Testing Protocol

### Test Setup:
1. **Choose your logging method** (I recommend Option 2 WiFi or Option 3 File)
2. **Plan a known route** (e.g., walk around block = 0.25 mi)
3. **Do 3 tests**: Main screen, Program workout, Challenge workout

### Using File Logger (Option 3):

**Test A - Main Screen:**
```bash
1. Open RuckTracker on iPhone
2. Start workout from main screen
3. Walk your route (with iPhone in pocket)
4. End workout, note final distance
5. Use Files app or Xcode to get log file
6. Rename it to: mainscreen_test.txt
```

**Test B - Program:**
```bash
1. Start workout from program
2. Walk SAME route
3. End workout, note final distance  
4. Get log file
5. Rename to: program_test.txt
```

**Test C - Challenge:**
```bash
1. Start workout from challenge
2. Walk SAME route
3. End workout, note final distance
4. Get log file
5. Rename to: challenge_test.txt
```

### Compare Logs:
```bash
# Look for differences in:
- Time between GPS updates (should be 5-10 seconds)
- Number of GPS updates (more = better)
- GPS accuracy values (lower = better)
- Weight initialization (should NOT be 0!)
```

---

## 📊 Example Comparison

**Good GPS Tracking:**
```
[12:35:15] 📍 GPS: First location acquired | Accuracy: 8.5m
[12:35:23] 📍 GPS update: +12.5m | Total: 0.008 mi | Accuracy: 7.2m
[12:35:28] 📍 GPS update: +15.3m | Total: 0.017 mi | Accuracy: 6.8m
[12:35:35] 📍 GPS update: +11.2m | Total: 0.024 mi | Accuracy: 5.9m
...14 more GPS updates...
Final: 0.24 mi ✅
```

**Bad GPS Tracking:**
```
[12:35:15] 📍 GPS: First location acquired | Accuracy: 25.0m
[12:35:48] 📍 GPS update: +125.5m | Total: 0.078 mi | Accuracy: 45.2m
[12:36:15] 📍 GPS update: movement < 5m (ignored)
...only 3 total GPS updates...
Final: 0.08 mi ❌ (should be ~0.25!)
```

**Key Difference**: Frequent GPS updates (every 5-10 sec) vs sparse updates (30+ sec gaps)

---

## 🚀 My Recommendation

**For your case** (testing distance undercalculation):

1. **Use Option 3 (File Logging)** - gives you permanent records to compare
2. **Walk the same outdoor route 3 times**:
   - Once from main screen
   - Once from program workout  
   - Once from challenge workout
3. **After each walk, grab the log file** via Files app (easiest)
4. **AirDrop all 3 logs to your Mac**
5. **Compare them side-by-side** in a text editor

The timestamps will show you **exactly** where GPS tracking differs!

---

## 📱 Viewing Logs on iPhone (Bonus)

If you want to see logs right on the phone without transferring files, I can add a simple log viewer screen in Settings. Just let me know!

---

## ✅ Summary

| Method | Range | Real-Time | Setup | Best For |
|--------|-------|-----------|-------|----------|
| Console + USB | Cable length | ✅ Yes | None | Quick tests |
| Console + WiFi | WiFi range | ✅ Yes | One-time | Indoor tests |
| **File Logging** | **Unlimited** | ❌ After | **None** | **Outdoor tests** |

**For distance testing → Use File Logging!** 🎯

The log files will show us the exact difference in GPS update frequency between the two code paths.

