package com.artless.rucktracker.health

import android.content.Context
import android.content.Intent
import android.util.Log
import com.artless.rucktracker.BuildConfig
import androidx.health.connect.client.records.metadata.Metadata
import androidx.activity.result.contract.ActivityResultContract
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CancellationException

@Singleton
class HealthConnectManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    val permissions = setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class)
    )

    private val prefs = context.getSharedPreferences("health_connect", Context.MODE_PRIVATE)

    fun isAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    fun requestPermissionsContract(): ActivityResultContract<Set<String>, Set<String>> =
        PermissionController.createRequestPermissionResultContract()

    suspend fun hasPermissions(): Boolean {
        if (!isAvailable()) return false
        return try {
            HealthConnectClient.getOrCreate(context).permissionController
                .getGrantedPermissions()
                .containsAll(permissions)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Could not check Health Connect permissions", e)
            false
        }
    }

    /** Heart rate is optional, so we only prompt once; users can grant it later in Health Connect. */
    suspend fun shouldPromptForPermissions(): Boolean =
        isAvailable() && !prefs.getBoolean(KEY_PROMPTED, false) && !hasPermissions()

    fun markPrompted() {
        prefs.edit().putBoolean(KEY_PROMPTED, true).apply()
    }

    /** Opens Health Connect's own permission screen, for users who already denied the in-app prompt. */
    fun settingsIntent(): Intent = Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)

    /** Callers check [hasPermissions] first; returns null when no wearable has written a recent sample. */
    suspend fun getLatestHeartRate(): Double? {
        return try {
            val now = Instant.now()
            val response = HealthConnectClient.getOrCreate(context).readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(now.minusSeconds(30), now)
                )
            )
            response.records.lastOrNull()?.samples?.lastOrNull()?.beatsPerMinute?.toDouble()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Heart rate read failed", e)
            null
        }
    }

    /**
     * Debug builds only: stands in for a wearable by writing one heart rate sample to
     * Health Connect, so the live tile and summary can be tested without a watch.
     * The write permission is never requested in-app (so the prompt matches release);
     * grant it with `adb shell pm grant com.artless.rucktracker android.permission.health.WRITE_HEART_RATE`.
     */
    suspend fun writeDemoHeartRate(bpm: Long) {
        if (!BuildConfig.DEBUG) return
        try {
            val now = Instant.now()
            HealthConnectClient.getOrCreate(context).insertRecords(
                listOf(
                    HeartRateRecord(
                        startTime = now.minusSeconds(1),
                        startZoneOffset = null,
                        endTime = now,
                        endZoneOffset = null,
                        samples = listOf(HeartRateRecord.Sample(now, bpm)),
                        metadata = Metadata()
                    )
                )
            )
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Demo heart rate write failed", e)
        }
    }

    companion object {
        private const val TAG = "HealthConnectManager"
        private const val KEY_PROMPTED = "heart_rate_prompted"
    }
}
