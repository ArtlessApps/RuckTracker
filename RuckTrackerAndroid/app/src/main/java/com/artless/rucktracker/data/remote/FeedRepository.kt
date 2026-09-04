package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.model.ClubPost
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeedRepository @Inject constructor(private val client: SupabaseClient) {

    suspend fun loadClubFeed(clubId: String, limit: Int = 50): List<ClubPost> =
        client.postgrest.rpc(
            "get_club_feed",
            buildJsonObject {
                put("p_club_id", clubId)
                put("p_limit", limit)
            }
        ).decodeList()

    suspend fun postWorkout(
        clubId: String,
        userId: String,
        workoutId: String,
        distanceMiles: Double,
        durationMinutes: Double,
        weightLbs: Double,
        calories: Double,
        elevationGain: Double
    ) {
        client.postgrest.from("club_posts")
            .insert(buildJsonObject {
                put("club_id", clubId)
                put("user_id", userId)
                put("post_type", "workout")
                put("workout_id", workoutId)
                put("distance_miles", distanceMiles)
                put("duration_minutes", durationMinutes)
                put("weight_lbs", weightLbs)
                put("calories", calories)
                put("elevation_gain", elevationGain)
            })
        client.postgrest.rpc(
            "update_leaderboard_entry",
            buildJsonObject {
                put("p_club_id", clubId)
                put("p_user_id", userId)
                put("p_distance", distanceMiles)
                put("p_weight", weightLbs)
                put("p_elevation", elevationGain)
            }
        )
    }

    suspend fun likePost(postId: String, userId: String) {
        client.postgrest.from("post_likes")
            .insert(buildJsonObject {
                put("post_id", postId)
                put("user_id", userId)
            })
    }

    suspend fun unlikePost(postId: String, userId: String) {
        client.postgrest.from("post_likes")
            .delete { filter { eq("post_id", postId); eq("user_id", userId) } }
    }

    suspend fun postEventComment(eventId: String, clubId: String, userId: String, content: String) {
        client.postgrest.from("club_posts")
            .insert(buildJsonObject {
                put("club_id", clubId)
                put("user_id", userId)
                put("post_type", "event_comment")
                put("event_id", eventId)
                put("content", content)
            })
    }

    suspend fun loadEventComments(eventId: String): List<ClubPost> =
        client.postgrest.from("club_posts")
            .select(columns = Columns.raw("*, profiles!club_posts_user_id_fkey(username, avatar_url)")) {
                filter {
                    eq("event_id", eventId)
                    eq("post_type", "event_comment")
                }
            }
            .decodeList()
}

@Singleton
class LeaderboardRepository @Inject constructor(private val client: SupabaseClient) {

    suspend fun loadWeeklyLeaderboard(clubId: String) =
        client.postgrest.rpc(
            "get_weekly_leaderboard",
            buildJsonObject { put("p_club_id", clubId) }
        ).decodeList<com.artless.rucktracker.data.model.LeaderboardEntry>()

    suspend fun updateGlobalLeaderboard(userId: String, distance: Double, elevation: Double, tonnage: Double) {
        client.postgrest.rpc(
            "update_global_leaderboard_entry",
            buildJsonObject {
                put("p_user_id", userId)
                put("p_distance", distance)
                put("p_elevation", elevation)
                put("p_tonnage", tonnage)
            }
        )
    }

    suspend fun fetchGlobalLeaderboard(type: com.artless.rucktracker.data.model.GlobalLeaderboardType): List<com.artless.rucktracker.data.model.GlobalLeaderboardEntry> =
        client.postgrest.from(type.tableName)
            .select(columns = Columns.ALL) {
                order(column = "rank", order = io.github.jan.supabase.postgrest.query.Order.ASCENDING)
                limit(100)
            }
            .decodeList()
}
