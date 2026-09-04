package com.artless.rucktracker.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

enum class RuckingGoal(val displayName: String) {
    LONGEVITY("Longevity & Health"),
    WEIGHT_LOSS("Burn Calories"),
    HIKING("Hiking & Hunting"),
    GORUCK_BASIC("GORUCK Basic"),
    GORUCK_TOUGH("GORUCK Tough"),
    MILITARY("Military Selection");

    companion object {
        fun fromRaw(value: String?): RuckingGoal =
            entries.find { it.name.equals(value, ignoreCase = true) || it.displayName == value }
                ?: LONGEVITY
    }
}

enum class ExperienceLevel(val displayName: String) {
    BEGINNER("New to Rucking"),
    INTERMEDIATE("Hiker / Runner"),
    ADVANCED("Ruck Pro");

    companion object {
        fun fromRaw(value: String?): ExperienceLevel =
            entries.find { it.name.equals(value, ignoreCase = true) || it.displayName == value }
                ?: BEGINNER
    }
}

enum class WeightUnit(val raw: String) {
    POUNDS("lbs"),
    KILOGRAMS("kg")
}

enum class DistanceUnit(val raw: String) {
    MILES("mi"),
    KILOMETERS("km")
}

enum class MainTab {
    RUCK, PLAN, TRIBE, RANKINGS, YOU
}

enum class PremiumFeature {
    TRAINING_PROGRAMS,
    WEEKLY_CHALLENGES,
    PLAN_EXECUTION,
    ADVANCED_ANALYTICS,
    EXPORT_DATA,
    GLOBAL_LEADERBOARDS,
    BASIC_TRACKING,
    CLUB_ACCESS,
    LOCAL_LEADERBOARDS;

    val requiresPremium: Boolean
        get() = when (this) {
            CLUB_ACCESS, LOCAL_LEADERBOARDS -> false
            else -> true
        }
}

enum class GlobalLeaderboardType(val tableName: String, val displayName: String) {
    DISTANCE("global_leaderboard_distance_weekly", "Road Warriors"),
    TONNAGE("global_leaderboard_tonnage_alltime", "Heavy Haulers"),
    ELEVATION("global_leaderboard_elevation_monthly", "Vertical Gainers"),
    CONSISTENCY("global_leaderboard_consistency", "Iron Discipline")
}

enum class ClubRole(val raw: String) {
    FOUNDER("founder"),
    LEADER("leader"),
    MEMBER("member")
}

enum class RsvpStatus(val raw: String) {
    GOING("going"),
    MAYBE("maybe"),
    OUT("out")
}

enum class PaywallContext {
    ONBOARDING, PLAN_GENERATION, PROGRAM_ACCESS, SETTINGS, FEATURE_UPSELL, PROFILE_UPGRADE, WORKOUT_START
}

@Serializable
data class UserProfile(
    val id: String,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val bio: String? = null,
    val location: String? = null,
    @SerialName("total_distance") val totalDistance: Double = 0.0,
    @SerialName("total_workouts") val totalWorkouts: Int = 0,
    @SerialName("current_streak") val currentStreak: Int = 0,
    @SerialName("longest_streak") val longestStreak: Int = 0,
    @SerialName("is_premium") val isPremium: Boolean = false,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class UserSubscription(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("subscription_type") val subscriptionType: String,
    val status: String,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("expires_at") val expiresAt: String? = null,
    @SerialName("apple_transaction_id") val transactionId: String? = null
)

@Serializable
data class Club(
    val id: String,
    val name: String,
    val description: String? = null,
    @SerialName("join_code") val joinCode: String,
    @SerialName("created_by") val createdBy: String,
    @SerialName("is_private") val isPrivate: Boolean = false,
    val zipcode: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    @SerialName("member_count") val memberCount: Int = 0
)

@Serializable
data class ClubMember(
    @SerialName("user_id") val userId: String,
    @SerialName("club_id") val clubId: String,
    val role: String = "member",
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null
)

@Serializable
data class ClubPost(
    val id: String,
    @SerialName("club_id") val clubId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("post_type") val postType: String = "workout",
    @SerialName("workout_id") val workoutId: String? = null,
    @SerialName("distance_miles") val distanceMiles: Double? = null,
    @SerialName("duration_minutes") val durationMinutes: Double? = null,
    @SerialName("weight_lbs") val weightLbs: Double? = null,
    val calories: Double? = null,
    @SerialName("elevation_gain") val elevationGain: Double? = null,
    val content: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("like_count") val likeCount: Int = 0,
    @SerialName("is_liked") val isLiked: Boolean = false
)

@Serializable
data class LeaderboardEntry(
    val rank: Int = 0,
    @SerialName("user_id") val userId: String,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("total_distance") val totalDistance: Double = 0.0,
    @SerialName("total_elevation") val totalElevation: Double = 0.0,
    @SerialName("total_workouts") val totalWorkouts: Int = 0
)

@Serializable
data class GlobalLeaderboardEntry(
    @SerialName("user_id") val userId: String,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_premium") val isPremium: Boolean = false,
    val score: Double = 0.0,
    val rank: Int = 0
)

@Serializable
data class ClubEvent(
    val id: String,
    @SerialName("club_id") val clubId: String,
    @SerialName("created_by") val createdBy: String,
    val title: String,
    val description: String? = null,
    @SerialName("start_time") val startTime: String,
    @SerialName("location_lat") val locationLat: Double? = null,
    @SerialName("location_long") val locationLong: Double? = null,
    @SerialName("address_text") val addressText: String? = null,
    @SerialName("meeting_point_description") val meetingPointDescription: String? = null,
    @SerialName("required_weight") val requiredWeight: Double? = null,
    @SerialName("water_requirements") val waterRequirements: String? = null
)

@Serializable
data class EventRsvp(
    val id: String? = null,
    @SerialName("event_id") val eventId: String,
    @SerialName("user_id") val userId: String,
    val status: String,
    @SerialName("declared_weight") val declaredWeight: Double? = null,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null
)

@Serializable
data class EventComment(
    val id: String,
    @SerialName("event_id") val eventId: String,
    @SerialName("user_id") val userId: String,
    val content: String,
    @SerialName("created_at") val createdAt: String? = null,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null
)

@Serializable
data class EmergencyContact(
    val name: String,
    val phone: String,
    val relationship: String? = null
)

@Serializable
data class ProgramJson(
    val id: String,
    val title: String,
    val description: String,
    @SerialName("durationWeeks") val durationWeeks: Int,
    val difficulty: String,
    val category: String? = null,
    @SerialName("isFeatured") val isFeatured: Boolean = false,
    @SerialName("isActive") val isActive: Boolean = true
) {
    val name: String get() = title
}

@Serializable
data class ChallengeJson(
    val id: String,
    val name: String,
    val description: String,
    @SerialName("duration_days") val durationDays: Int,
    @SerialName("focus_area") val focusArea: String,
    @SerialName("is_active") val isActive: Boolean = true
)
