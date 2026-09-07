package com.artless.rucktracker.data.remote

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.serializer.KotlinXSerializer
import kotlinx.serialization.json.Json

object SupabaseClientProvider {
    private const val SUPABASE_URL = "https://myqlnifrvmhetsghwrpm.supabase.co"
    private const val SUPABASE_ANON_KEY = "sb_publishable_g7C7bFmxE77NOpeWikCQnw_0zI43Paw"

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
        coerceInputValues = true
    }

    val client = createSupabaseClient(
        supabaseUrl = SUPABASE_URL,
        supabaseKey = SUPABASE_ANON_KEY
    ) {
        defaultSerializer = KotlinXSerializer(json)
        install(Auth)
        install(Postgrest)
    }
}
