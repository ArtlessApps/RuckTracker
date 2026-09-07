package com.artless.rucktracker.domain

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeedbackSupport @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /**
     * Opens the system email client with a pre-filled message to hello@artless.app.
     * @param launchContext Activity context preferred (e.g. LocalContext). Falls back to
     * application context with NEW_TASK if none is provided.
     */
    fun sendFeedback(
        launchContext: Context = context,
        subject: String = "MARCH Android Feedback",
        message: String = ""
    ) {
        val appVersion = runCatching {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            val versionName = info.versionName ?: "unknown"
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toString()
            }
            "$versionName ($versionCode)"
        }.getOrDefault("unknown")

        val body = buildString {
            appendLine("App: $appVersion")
            appendLine("Android: ${Build.VERSION.RELEASE}")
            appendLine("Device: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine()
            if (message.isNotBlank()) append(message)
        }

        // Subject/body must live in the mailto URI — ACTION_SENDTO extras are often ignored.
        val mailto = Uri.parse("mailto:$SUPPORT_EMAIL").buildUpon()
            .appendQueryParameter("subject", subject)
            .appendQueryParameter("body", body)
            .build()

        try {
            val intent = Intent(Intent.ACTION_SENDTO, mailto)
            val chooser = Intent.createChooser(intent, "Send feedback").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            launchContext.startActivity(chooser)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open email client for feedback", e)
        }
    }

    private companion object {
        const val SUPPORT_EMAIL = "hello@artless.app"
        const val TAG = "FeedbackSupport"
    }
}

@Singleton
class GoogleSignInHelper @Inject constructor(
    @ApplicationContext private val context: Context
) {
    // Google Sign-In via Supabase OAuth — configure in Supabase dashboard with Android client ID
    fun getOAuthRedirectUri(): String = "com.artless.rucktracker://login-callback"
}
