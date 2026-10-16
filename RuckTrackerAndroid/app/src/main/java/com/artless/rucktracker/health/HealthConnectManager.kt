package com.artless.rucktracker.health

import android.content.Context
import android.content.Intent
import android.util.Log
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

    companion object {
        private const val TAG = "HealthConnectManager"
        private const val KEY_PROMPTED = "heart_rate_prompted"
    }
}
