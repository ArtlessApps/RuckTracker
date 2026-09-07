package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.model.ClubEvent
import com.artless.rucktracker.data.model.EventRsvp
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class EventRepository @Inject constructor(private val client: SupabaseClient) {

    suspend fun loadClubEvents(clubId: String): List<ClubEvent> =
        client.postgrest.from("club_events")
            .select(columns = Columns.ALL) {
                filter { eq("club_id", clubId) }
                order("start_time", Order.ASCENDING)
            }
            .decodeList()

    suspend fun createEvent(
        clubId: String,
        createdBy: String,
        title: String,
        description: String?,
        startTime: String,
        lat: Double?,
        lon: Double?,
        address: String?
    ): ClubEvent =
        client.postgrest.from("club_events")
            .insert(buildJsonObject {
                put("club_id", clubId)
                put("created_by", createdBy)
                put("title", title)
                description?.let { put("description", it) }
                put("start_time", startTime)
                lat?.let { put("location_lat", it) }
                lon?.let { put("location_long", it) }
                address?.let { put("address_text", it) }
            }) { select() }
            .decodeSingle()

    suspend fun updateEvent(eventId: String, title: String, description: String?, startTime: String) {
        client.postgrest.from("club_events")
            .update(buildJsonObject {
                put("title", title)
                description?.let { put("description", it) }
                put("start_time", startTime)
            }) { filter { eq("id", eventId) } }
    }

    suspend fun deleteEvent(eventId: String) {
        client.postgrest.from("club_events").delete { filter { eq("id", eventId) } }
    }

    suspend fun rsvpToEvent(eventId: String, userId: String, status: String, declaredWeight: Int?) {
        val existing = getUserRsvp(eventId, userId)
        val payload = buildJsonObject {
            put("event_id", eventId)
            put("user_id", userId)
            put("status", status)
            // Column is integer — Doubles like 45.0 cause "invalid input syntax for type integer"
            declaredWeight?.let { put("declared_weight", it) }
        }
        if (existing != null) {
            client.postgrest.from("event_rsvps")
                .update(payload) { filter { eq("event_id", eventId); eq("user_id", userId) } }
        } else {
            client.postgrest.from("event_rsvps").insert(payload)
        }
    }

    suspend fun loadEventRsvps(eventId: String): List<EventRsvp> =
        client.postgrest.from("event_rsvps")
            .select(columns = Columns.raw("*, profiles!inner(username, avatar_url)")) {
                filter { eq("event_id", eventId) }
            }
            .decodeList()

    suspend fun getUserRsvp(eventId: String, userId: String): EventRsvp? =
        client.postgrest.from("event_rsvps")
            .select(columns = Columns.ALL) {
                filter { eq("event_id", eventId); eq("user_id", userId) }
            }
            .decodeSingleOrNull()
}
