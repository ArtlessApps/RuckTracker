package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.model.UserProfile
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val client: SupabaseClient
) {
    val sessionStatus: StateFlow<SessionStatus> = client.auth.sessionStatus

    val currentUserId: String?
        get() = (sessionStatus.value as? SessionStatus.Authenticated)?.session?.user?.id

    val isAuthenticated: Boolean
        get() = sessionStatus.value is SessionStatus.Authenticated

    suspend fun isUsernameAvailable(username: String): Boolean {
        return client.postgrest.rpc(
            function = "is_username_available",
            parameters = buildJsonObject { put("p_username", username) }
        ).decodeAs()
    }

    suspend fun signUp(email: String, username: String, password: String) {
        client.auth.signUpWith(Email) {
            this.email = email.trim().lowercase()
            this.password = password
            data = buildJsonObject { put("username", username) }
        }
    }

    suspend fun signIn(email: String, password: String) {
        client.auth.signInWith(Email) {
            this.email = email.trim().lowercase()
            this.password = password
        }
    }

    suspend fun signOut() {
        client.auth.signOut()
    }

    suspend fun deleteAccount() {
        client.postgrest.rpc("delete_user_account")
        client.auth.signOut()
    }

    suspend fun fetchProfile(userId: String): UserProfile {
        return client.postgrest.from("profiles")
            .select(columns = Columns.list(
                "id", "username", "avatar_url", "bio", "location",
                "total_distance", "total_workouts", "current_streak", "longest_streak",
                "is_premium", "created_at"
            )) {
                filter { eq("id", userId) }
            }
            .decodeSingle()
    }
}
