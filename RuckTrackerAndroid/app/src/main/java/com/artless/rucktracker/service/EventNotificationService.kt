package com.artless.rucktracker.service

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.artless.rucktracker.R
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class EventNotificationService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun scheduleEventReminder(eventId: String, eventTitle: String, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, EventReminderReceiver::class.java).apply {
            putExtra("event_title", eventTitle)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            eventId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
    }
}

class EventReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("event_title") ?: "Club Event"
        val notification = NotificationCompat.Builder(context, "event_reminders")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("MARCH Event Reminder")
            .setContentText(title)
            .build()
        NotificationManagerCompat.from(context).notify(title.hashCode(), notification)
    }
}
