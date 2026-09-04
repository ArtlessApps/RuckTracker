package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.model.DistanceUnit
import com.artless.rucktracker.data.model.ExperienceLevel
import com.artless.rucktracker.data.model.RuckingGoal
import com.artless.rucktracker.data.model.WeightUnit
import com.artless.rucktracker.data.settings.UserSettingsState
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
data class UserPreferencesRow(
    @SerialName("user_id") val userId: String,
    @SerialName("body_weight") val bodyWeight: Double? = null,
    @SerialName("preferred_weight_unit") val preferredWeightUnit: String? = null,
    @SerialName("preferred_distance_unit") val preferredDistanceUnit: String? = null,
    @SerialName("default_ruck_weight") val defaultRuckWeight: Double? = null,
    @SerialName("rucking_goal") val ruckingGoal: String? = null,
    @SerialName("experience_level") val experienceLevel: String? = null,
    @SerialName("preferred_training_days") val preferredTrainingDays: List<Int>? = null,
    @SerialName("active_program_id") val activeProgramId: String? = null,
    @SerialName("target_event_date") val targetEventDate: String? = null,
    @SerialName("baseline_pace_minutes_per_mile") val baselinePaceMinutesPerMile: Double? = null,
    @SerialName("baseline_longest_distance_miles") val baselineLongestDistanceMiles: Double? = null,
    @SerialName("has_hill_access") val hasHillAccess: Boolean? = null,
    @SerialName("has_stairs_access") val hasStairsAccess: Boolean? = null,
    @SerialName("has_completed_onboarding") val hasCompletedOnboarding: Boolean? = null
)

@Singleton
class PreferencesRepository @Inject constructor(private val client: SupabaseClient) {

    suspend fun loadPreferences(userId: String): UserSettingsState? {
        return runCatching {
            client.postgrest.from("user_preferences")
                .select(columns = Columns.ALL) { filter { eq("user_id", userId) } }
                .decodeSingleOrNull<UserPreferencesRow>()
                ?.toSettingsState()
        }.getOrNull()
    }

    suspend fun savePreferences(userId: String, settings: UserSettingsState) {
        client.postgrest.from("user_preferences")
            .upsert(buildJsonObject {
                put("user_id", userId)
                put("body_weight", settings.bodyWeight)
                put("preferred_weight_unit", settings.preferredWeightUnit.raw)
                put("preferred_distance_unit", settings.preferredDistanceUnit.raw)
                put("default_ruck_weight", settings.defaultRuckWeight)
                put("rucking_goal", settings.ruckingGoal.displayName)
                put("experience_level", settings.experienceLevel.displayName)
                put(
                    "preferred_training_days",
                    JsonArray(settings.preferredTrainingDays.map { JsonPrimitive(it) })
                )
                settings.activeProgramId?.let { put("active_program_id", it) }
                settings.targetEventDate?.let { put("target_event_date", it.toString()) }
                put("baseline_pace_minutes_per_mile", settings.baselinePaceMinutesPerMile)
                put("baseline_longest_distance_miles", settings.baselineLongestDistanceMiles)
                put("has_hill_access", settings.hasHillAccess)
                put("has_stairs_access", settings.hasStairsAccess)
                put("has_completed_onboarding", settings.hasCompletedOnboarding)
            }) {
                onConflict = "user_id"
            }
    }

    private fun UserPreferencesRow.toSettingsState(): UserSettingsState {
        val weightUnit = when (preferredWeightUnit?.lowercase()) {
            "kg", "kilograms" -> WeightUnit.KILOGRAMS
            else -> WeightUnit.POUNDS
        }
        val distanceUnit = when (preferredDistanceUnit?.lowercase()) {
            "km", "kilometers" -> DistanceUnit.KILOMETERS
            else -> DistanceUnit.MILES
        }
        return UserSettingsState(
            bodyWeight = bodyWeight ?: 180.0,
            defaultRuckWeight = defaultRuckWeight ?: 20.0,
            preferredWeightUnit = weightUnit,
            preferredDistanceUnit = distanceUnit,
            ruckingGoal = RuckingGoal.fromRaw(ruckingGoal),
            experienceLevel = ExperienceLevel.fromRaw(experienceLevel),
            preferredTrainingDays = preferredTrainingDays?.takeIf { it.isNotEmpty() } ?: listOf(2, 4, 7),
            activeProgramId = activeProgramId,
            targetEventDate = targetEventDate?.let { runCatching { java.time.Instant.parse(it).toEpochMilli() }.getOrNull() },
            baselinePaceMinutesPerMile = baselinePaceMinutesPerMile ?: 16.0,
            baselineLongestDistanceMiles = baselineLongestDistanceMiles ?: 4.0,
            hasHillAccess = hasHillAccess ?: true,
            hasStairsAccess = hasStairsAccess ?: false,
            hasCompletedOnboarding = hasCompletedOnboarding ?: false
        )
    }
}
