package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.model.UserProfile
import com.artless.rucktracker.data.model.UserSubscription
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ProfileRepository @Inject constructor(private val client: SupabaseClient) {

    suspend fun fetchProfile(userId: String): UserProfile =
        client.postgrest.from("profiles")
            .select(columns = Columns.ALL) { filter { eq("id", userId) } }
            .decodeSingle()

    suspend fun updatePremiumStatus(userId: String, isPremium: Boolean) {
        client.postgrest.from("profiles")
            .update(buildJsonObject { put("is_premium", isPremium) }) {
                filter { eq("id", userId) }
            }
    }

    suspend fun updateUsername(userId: String, username: String) {
        client.postgrest.from("profiles")
            .update(buildJsonObject { put("username", username) }) {
                filter { eq("id", userId) }
            }
    }
}

@Singleton
class SubscriptionRepository @Inject constructor(
    private val client: SupabaseClient,
    private val profileRepository: ProfileRepository
) {
    suspend fun getActiveSubscription(userId: String): UserSubscription? {
        return runCatching {
            client.postgrest.from("user_subscriptions")
                .select(columns = Columns.ALL) {
                    filter {
                        eq("user_id", userId)
                        eq("status", "active")
                        neq("subscription_type", "ambassador")
                    }
                    order("created_at", Order.DESCENDING)
                    limit(1)
                }
                .decodeSingleOrNull<UserSubscription>()
        }.getOrNull()
    }

    suspend fun recordSubscription(
        userId: String,
        type: String,
        transactionId: String,
        expiresAt: String?
    ) {
        expireActiveSubscriptions(userId)
        client.postgrest.from("user_subscriptions")
            .insert(buildJsonObject {
                put("user_id", userId)
                put("subscription_type", type)
                put("status", "active")
                put("apple_transaction_id", transactionId)
                expiresAt?.let { put("expires_at", it) }
            })
        profileRepository.updatePremiumStatus(userId, true)
    }

    suspend fun recordAmbassadorSubscription(userId: String) {
        expireActiveSubscriptions(userId)
        client.postgrest.from("user_subscriptions")
            .insert(buildJsonObject {
                put("user_id", userId)
                put("subscription_type", "ambassador")
                put("status", "active")
            })
        profileRepository.updatePremiumStatus(userId, true)
    }

    suspend fun expireSubscription(userId: String) {
        expireActiveSubscriptions(userId)
        profileRepository.updatePremiumStatus(userId, false)
    }

    private suspend fun expireActiveSubscriptions(userId: String) {
        client.postgrest.from("user_subscriptions")
            .update(buildJsonObject { put("status", "expired") }) {
                filter {
                    eq("user_id", userId)
                    eq("status", "active")
                }
            }
    }
}
