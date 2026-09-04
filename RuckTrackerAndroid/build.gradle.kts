plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt) apply false
}

// This repo lives under ~/Documents, which macOS iCloud Drive syncs. iCloud
// resolves its own write races by dropping "<name> 2.class" copies into
// build/intermediates, which then makes D8 fail with "Type ... is defined
// multiple times". Keeping build output outside the synced tree avoids it.
val syncSafeBuildRoot = File(System.getProperty("user.home"), "Library/Caches/MarchAndroidBuild")
allprojects {
    val relative = if (path == ":") "root" else path.removePrefix(":").replace(':', '/')
    layout.buildDirectory.set(File(syncSafeBuildRoot, relative))
}
