package com.artless.rucktracker.health

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class HealthConnectManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    val permissions = setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class)
    )

    suspend fun isAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    suspend fun getLatestHeartRate(): Double? {
        if (!isAvailable()) return null
        val client = HealthConnectClient.getOrCreate(context)
        val now = Instant.now()
        val response = client.readRecords(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = TimeRangeFilter.between(now.minusSeconds(30), now)
            )
        )
        return response.records.lastOrNull()?.samples?.lastOrNull()?.beatsPerMinute?.toDouble()
    }
}
