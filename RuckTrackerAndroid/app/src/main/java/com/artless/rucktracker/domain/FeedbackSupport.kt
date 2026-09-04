package com.artless.rucktracker.domain

import android.content.Context
import android.content.Intent
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeedbackSupport @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun sendFeedback(subject: String = "MARCH Android Feedback", body: String = "") {
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = android.net.Uri.parse("mailto:hello@artless.app")
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
        }
        context.startActivity(Intent.createChooser(intent, "Send feedback"))
    }
}

@Singleton
class GoogleSignInHelper @Inject constructor(
    @ApplicationContext private val context: Context
) {
    // Google Sign-In via Supabase OAuth — configure in Supabase dashboard with Android client ID
    fun getOAuthRedirectUri(): String = "com.artless.rucktracker://login-callback"
}
