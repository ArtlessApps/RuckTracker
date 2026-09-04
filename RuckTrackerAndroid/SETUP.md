# MARCH Android — First-Time Setup

If you've built iOS in Xcode but never Android, start here.

## 1. Install Android Studio

Download from [developer.android.com/studio](https://developer.android.com/studio) and install with default options (includes Android SDK + emulator).

## 2. Open the project

1. Android Studio → **File → Open**
2. Select the **`RuckTrackerAndroid/`** folder (not the repo root)
3. Wait for **Gradle Sync** to finish (bottom status bar). First sync can take several minutes.

If sync fails, Android Studio will prompt to install missing SDK components — accept them.

## 3. Run on a physical phone (recommended)

GPS and background tracking need a real device.

1. On your Android phone: **Settings → About phone → tap Build number 7 times** to enable Developer options
2. **Settings → Developer options → USB debugging** → ON
3. Connect phone via USB; tap **Allow** on the debug prompt
4. In Android Studio, select your phone from the device dropdown (top toolbar)
5. Click the green **Run** button

## 4. Run on an emulator (UI only)

1. **Tools → Device Manager → Create Virtual Device**
2. Pick a Pixel device, API 34 or 35 system image
3. Run the app on the emulator

Use emulator for auth/UI. Use a **physical phone** for workout GPS testing.

## 5. Build from terminal

```bash
cd RuckTrackerAndroid
./gradlew assembleDebug
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`

## 6. View crash logs

Android Studio → **Logcat** tab → filter by `com.artless.rucktracker`

## Next steps

- **[QA_CHECKLIST.md](QA_CHECKLIST.md)** — what to test before release
- **[BILLING_TEST_SETUP.md](BILLING_TEST_SETUP.md)** — Play Console subscription testing
- **[PLAYSTORE.md](PLAYSTORE.md)** — submission checklist
