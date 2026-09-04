package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.model.Club
import com.artless.rucktracker.data.model.ClubMember
import com.artless.rucktracker.data.model.EmergencyContact
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ClubRepository @Inject constructor(private val client: SupabaseClient) {

    suspend fun loadMyClubs(userId: String): List<Club> {
        return client.postgrest.from("clubs")
            .select(columns = Columns.raw("*, club_members!inner(user_id)")) {
                filter { eq("club_members.user_id", userId) }
            }
            .decodeList()
    }

    suspend fun getClubByCode(code: String): Club? =
        client.postgrest.from("clubs")
            .select(columns = Columns.ALL) { filter { eq("join_code", code.uppercase()) } }
            .decodeSingleOrNull()

    suspend fun getClub(clubId: String): Club? =
        client.postgrest.from("clubs")
            .select(columns = Columns.ALL) { filter { eq("id", clubId) } }
            .decodeSingleOrNull()

    suspend fun createClub(
        name: String,
        description: String,
        isPrivate: Boolean,
        zipcode: String?,
        createdBy: String,
        joinCode: String
    ): Club {
        val club = client.postgrest.from("clubs")
            .insert(buildJsonObject {
                put("name", name)
                put("description", description)
                put("is_private", isPrivate)
                zipcode?.let { put("zipcode", it) }
                put("created_by", createdBy)
                put("join_code", joinCode)
            }) { select() }
            .decodeSingle<Club>()
        joinClub(club.id, createdBy, "founder")
        return club
    }

    suspend fun joinClub(clubId: String, userId: String, role: String = "member") {
        client.postgrest.from("club_members")
            .insert(buildJsonObject {
                put("club_id", clubId)
                put("user_id", userId)
                put("role", role)
            })
    }

    suspend fun joinClubWithCode(code: String, userId: String): Club {
        val club = getClubByCode(code) ?: error("Club not found")
        joinClub(club.id, userId)
        return club
    }

    suspend fun leaveClub(clubId: String, userId: String) {
        client.postgrest.from("club_members")
            .delete { filter { eq("club_id", clubId); eq("user_id", userId) } }
    }

    suspend fun getUserRole(clubId: String, userId: String): String? =
        client.postgrest.from("club_members")
            .select(columns = Columns.list("role")) {
                filter { eq("club_id", clubId); eq("user_id", userId) }
            }
            .decodeSingleOrNull<Map<String, String>>()?.get("role")

    suspend fun loadClubMembers(clubId: String): List<ClubMember> =
        client.postgrest.from("club_members")
            .select(columns = Columns.raw("user_id, club_id, role, profiles!inner(username, avatar_url)")) {
                filter { eq("club_id", clubId) }
            }
            .decodeList()

    suspend fun signWaiver(clubId: String, userId: String, contact: EmergencyContact) {
        client.postgrest.from("club_members")
            .update(buildJsonObject {
                put("waiver_signed_at", "now()")
                put("emergency_contact_json", Json.encodeToString(EmergencyContact.serializer(), contact))
            }) {
                filter { eq("club_id", clubId); eq("user_id", userId) }
            }
    }

    suspend fun findPublicClubs(): List<Club> =
        client.postgrest.from("clubs")
            .select(columns = Columns.ALL) {
                filter { eq("is_private", false) }
                order("member_count", Order.DESCENDING)
                limit(20)
            }
            .decodeList()

    suspend fun findNearbyClubs(lat: Double, lon: Double, radiusMiles: Double = 50.0): List<Club> =
        client.postgrest.rpc(
            "find_nearby_clubs",
            buildJsonObject {
                put("user_lat", lat)
                put("user_lon", lon)
                put("radius_miles", radiusMiles)
            }
        ).decodeList()

    suspend fun deleteClub(clubId: String) {
        client.postgrest.from("clubs").delete { filter { eq("id", clubId) } }
    }

    suspend fun updateClub(clubId: String, name: String, description: String, isPrivate: Boolean, zipcode: String?) {
        client.postgrest.from("clubs")
            .update(buildJsonObject {
                put("name", name)
                put("description", description)
                put("is_private", isPrivate)
                zipcode?.let { put("zipcode", it) }
            }) { filter { eq("id", clubId) } }
    }

    suspend fun promoteToLeader(clubId: String, userId: String) {
        client.postgrest.from("club_members")
            .update(buildJsonObject { put("role", "leader") }) {
                filter { eq("club_id", clubId); eq("user_id", userId) }
            }
    }

    suspend fun demoteToMember(clubId: String, userId: String) {
        client.postgrest.from("club_members")
            .update(buildJsonObject { put("role", "member") }) {
                filter { eq("club_id", clubId); eq("user_id", userId) }
            }
    }

    suspend fun removeMember(clubId: String, userId: String) {
        client.postgrest.from("club_members")
            .delete { filter { eq("club_id", clubId); eq("user_id", userId) } }
    }
}
