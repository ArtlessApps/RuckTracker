package com.artless.rucktracker.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.artless.rucktracker.MainActivity
import com.artless.rucktracker.R
import com.artless.rucktracker.ui.workout.ActiveWorkoutState
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.util.Locale
import javax.inject.Inject

@AndroidEntryPoint
class WorkoutTrackingService : Service() {

    @Inject lateinit var sessionManager: WorkoutSessionManager

    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Main.immediate + serviceJob)
    private var observeJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                observeJob?.cancel()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_START, ACTION_UPDATE, null -> {
                val state = sessionManager.state.value
                if (!state.isActive && intent?.action != ACTION_START) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                promoteToForeground(state)
                observeSession()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        observeJob?.cancel()
        serviceJob.cancel()
        super.onDestroy()
    }

    private fun observeSession() {
        if (observeJob?.isActive == true) return
        observeJob = serviceScope.launch {
            sessionManager.state.collectLatest { state ->
                if (!state.isActive) return@collectLatest
                val manager = getSystemService(NotificationManager::class.java)
                manager.notify(NOTIFICATION_ID, buildNotification(state))
            }
        }
    }

    private fun promoteToForeground(state: ActiveWorkoutState) {
        val notification = buildNotification(state)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(state: ActiveWorkoutState): Notification {
        val channelId = "workout_tracking"
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(channelId, "Workout Tracking", NotificationManager.IMPORTANCE_LOW)
        )

        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_OPEN_ACTIVE_WORKOUT, true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val status = if (state.isPaused) "Paused" else "Ruck in progress"
        val detail = if (state.isActive) {
            String.format(
                Locale.US,
                "%s · %.2f mi · %s",
                status,
                state.distanceMiles,
                formatElapsed(state.elapsedSeconds)
            )
        } else {
            status
        }

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("MARCH")
            .setContentText(detail)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun formatElapsed(totalSeconds: Int): String {
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
        else String.format(Locale.US, "%d:%02d", minutes, seconds)
    }

    companion object {
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val ACTION_UPDATE = "update"
        const val EXTRA_OPEN_ACTIVE_WORKOUT = "open_active_workout"
        private const val NOTIFICATION_ID = 1001
    }
}
