package com.artless.rucktracker.data.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.artless.rucktracker.data.model.DistanceUnit
import com.artless.rucktracker.data.model.ExperienceLevel
import com.artless.rucktracker.data.model.RuckingGoal
import com.artless.rucktracker.data.model.WeightUnit
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "march_user_settings")

data class UserSettingsState(
    val bodyWeight: Double = 180.0,
    val defaultRuckWeight: Double = 20.0,
    val preferredWeightUnit: WeightUnit = WeightUnit.POUNDS,
    val preferredDistanceUnit: DistanceUnit = DistanceUnit.MILES,
    val ruckingGoal: RuckingGoal = RuckingGoal.LONGEVITY,
    val experienceLevel: ExperienceLevel = ExperienceLevel.BEGINNER,
    val preferredTrainingDays: List<Int> = listOf(2, 4, 7),
    val activeProgramId: String? = null,
    val targetEventDate: Long? = null,
    val baselinePaceMinutesPerMile: Double = 16.0,
    val baselineLongestDistanceMiles: Double = 4.0,
    val hasHillAccess: Boolean = true,
    val hasStairsAccess: Boolean = false,
    val hasCompletedOnboarding: Boolean = false,
    val username: String? = null,
    val email: String? = null
)

@Singleton
class UserSettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private object Keys {
        val BODY_WEIGHT = doublePreferencesKey("body_weight")
        val DEFAULT_RUCK_WEIGHT = doublePreferencesKey("default_ruck_weight")
        val WEIGHT_UNIT = stringPreferencesKey("weight_unit")
        val DISTANCE_UNIT = stringPreferencesKey("distance_unit")
        val RUCKING_GOAL = stringPreferencesKey("rucking_goal")
        val EXPERIENCE_LEVEL = stringPreferencesKey("experience_level")
        val TRAINING_DAYS = stringPreferencesKey("training_days")
        val ACTIVE_PROGRAM_ID = stringPreferencesKey("active_program_id")
        val TARGET_EVENT_DATE = longPreferencesKey("target_event_date")
        val BASELINE_PACE = doublePreferencesKey("baseline_pace")
        val BASELINE_DISTANCE = doublePreferencesKey("baseline_distance")
        val HAS_HILL_ACCESS = booleanPreferencesKey("has_hill_access")
        val HAS_STAIRS_ACCESS = booleanPreferencesKey("has_stairs_access")
        val HAS_COMPLETED_ONBOARDING = booleanPreferencesKey("has_completed_onboarding")
        val USERNAME = stringPreferencesKey("username")
        val EMAIL = stringPreferencesKey("email")
        val WORKOUT_COUNT = intPreferencesKey("workout_count_for_review")
    }

    val settings: Flow<UserSettingsState> = context.settingsDataStore.data.map { prefs ->
        UserSettingsState(
            bodyWeight = prefs[Keys.BODY_WEIGHT] ?: 180.0,
            defaultRuckWeight = prefs[Keys.DEFAULT_RUCK_WEIGHT] ?: 20.0,
            preferredWeightUnit = prefs[Keys.WEIGHT_UNIT]?.let { runCatching { WeightUnit.valueOf(it) }.getOrNull() } ?: WeightUnit.POUNDS,
            preferredDistanceUnit = prefs[Keys.DISTANCE_UNIT]?.let { runCatching { DistanceUnit.valueOf(it) }.getOrNull() } ?: DistanceUnit.MILES,
            ruckingGoal = RuckingGoal.fromRaw(prefs[Keys.RUCKING_GOAL]),
            experienceLevel = ExperienceLevel.fromRaw(prefs[Keys.EXPERIENCE_LEVEL]),
            preferredTrainingDays = prefs[Keys.TRAINING_DAYS]?.split(",")?.mapNotNull { it.toIntOrNull() } ?: listOf(2, 4, 7),
            activeProgramId = prefs[Keys.ACTIVE_PROGRAM_ID],
            targetEventDate = prefs[Keys.TARGET_EVENT_DATE],
            baselinePaceMinutesPerMile = prefs[Keys.BASELINE_PACE] ?: 16.0,
            baselineLongestDistanceMiles = prefs[Keys.BASELINE_DISTANCE] ?: 4.0,
            hasHillAccess = prefs[Keys.HAS_HILL_ACCESS] ?: true,
            hasStairsAccess = prefs[Keys.HAS_STAIRS_ACCESS] ?: false,
            hasCompletedOnboarding = prefs[Keys.HAS_COMPLETED_ONBOARDING] ?: false,
            username = prefs[Keys.USERNAME],
            email = prefs[Keys.EMAIL]
        )
    }

    suspend fun update(transform: (UserSettingsState) -> UserSettingsState) {
        val current = settings.first()
        val updated = transform(current)
        context.settingsDataStore.edit { prefs ->
            prefs[Keys.BODY_WEIGHT] = updated.bodyWeight
            prefs[Keys.DEFAULT_RUCK_WEIGHT] = updated.defaultRuckWeight
            prefs[Keys.WEIGHT_UNIT] = updated.preferredWeightUnit.name
            prefs[Keys.DISTANCE_UNIT] = updated.preferredDistanceUnit.name
            prefs[Keys.RUCKING_GOAL] = updated.ruckingGoal.name
            prefs[Keys.EXPERIENCE_LEVEL] = updated.experienceLevel.name
            prefs[Keys.TRAINING_DAYS] = updated.preferredTrainingDays.joinToString(",")
            updated.activeProgramId?.let { prefs[Keys.ACTIVE_PROGRAM_ID] = it }
            updated.targetEventDate?.let { prefs[Keys.TARGET_EVENT_DATE] = it }
            prefs[Keys.BASELINE_PACE] = updated.baselinePaceMinutesPerMile
            prefs[Keys.BASELINE_DISTANCE] = updated.baselineLongestDistanceMiles
            prefs[Keys.HAS_HILL_ACCESS] = updated.hasHillAccess
            prefs[Keys.HAS_STAIRS_ACCESS] = updated.hasStairsAccess
            prefs[Keys.HAS_COMPLETED_ONBOARDING] = updated.hasCompletedOnboarding
            updated.username?.let { prefs[Keys.USERNAME] = it }
            updated.email?.let { prefs[Keys.EMAIL] = it }
        }
    }

    suspend fun setOnboardingComplete(complete: Boolean) {
        context.settingsDataStore.edit { it[Keys.HAS_COMPLETED_ONBOARDING] = complete }
    }

    /**
     * Replace all settings (used when switching to a signed-in user).
     * Unlike [update], this does not merge with the previous account's values.
     */
    suspend fun replaceAll(state: UserSettingsState) {
        context.settingsDataStore.edit { prefs ->
            prefs.clear()
            prefs[Keys.BODY_WEIGHT] = state.bodyWeight
            prefs[Keys.DEFAULT_RUCK_WEIGHT] = state.defaultRuckWeight
            prefs[Keys.WEIGHT_UNIT] = state.preferredWeightUnit.name
            prefs[Keys.DISTANCE_UNIT] = state.preferredDistanceUnit.name
            prefs[Keys.RUCKING_GOAL] = state.ruckingGoal.name
            prefs[Keys.EXPERIENCE_LEVEL] = state.experienceLevel.name
            prefs[Keys.TRAINING_DAYS] = state.preferredTrainingDays.joinToString(",")
            state.activeProgramId?.let { prefs[Keys.ACTIVE_PROGRAM_ID] = it }
            state.targetEventDate?.let { prefs[Keys.TARGET_EVENT_DATE] = it }
            prefs[Keys.BASELINE_PACE] = state.baselinePaceMinutesPerMile
            prefs[Keys.BASELINE_DISTANCE] = state.baselineLongestDistanceMiles
            prefs[Keys.HAS_HILL_ACCESS] = state.hasHillAccess
            prefs[Keys.HAS_STAIRS_ACCESS] = state.hasStairsAccess
            prefs[Keys.HAS_COMPLETED_ONBOARDING] = state.hasCompletedOnboarding
            state.username?.let { prefs[Keys.USERNAME] = it }
            state.email?.let { prefs[Keys.EMAIL] = it }
        }
    }

    /** Reset to factory defaults so the next account does not inherit plan/onboarding. */
    suspend fun resetToDefaults() {
        replaceAll(UserSettingsState())
    }

    suspend fun getWorkoutCountForReview(): Int =
        context.settingsDataStore.data.first()[Keys.WORKOUT_COUNT] ?: 0

    suspend fun incrementWorkoutCountForReview() {
        context.settingsDataStore.edit { prefs ->
            prefs[Keys.WORKOUT_COUNT] = (prefs[Keys.WORKOUT_COUNT] ?: 0) + 1
        }
    }
}
