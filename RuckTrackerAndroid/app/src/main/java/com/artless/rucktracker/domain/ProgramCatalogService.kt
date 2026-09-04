package com.artless.rucktracker.domain

import android.content.Context
import com.artless.rucktracker.data.model.ChallengeJson
import com.artless.rucktracker.data.model.ProgramJson
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ProgramCatalogService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val json = Json { ignoreUnknownKeys = true }

    fun loadPrograms(): List<ProgramJson> = runCatching {
        val text = context.assets.open("Programs.json").bufferedReader().use { it.readText() }
        json.decodeFromString<List<ProgramJson>>(text)
    }.getOrDefault(emptyList())

    fun loadChallenges(): List<ChallengeJson> = runCatching {
        val text = context.assets.open("Challenges.json").bufferedReader().use { it.readText() }
        json.decodeFromString<List<ChallengeJson>>(text)
    }.getOrDefault(emptyList())
}
