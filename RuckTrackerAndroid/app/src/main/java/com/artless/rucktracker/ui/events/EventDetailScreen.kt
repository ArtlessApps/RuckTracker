package com.artless.rucktracker.ui.events

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.model.ClubEvent
import com.artless.rucktracker.ui.theme.MarchColors

@Composable
fun EventDetailScreen(
    event: ClubEvent,
    modifier: Modifier = Modifier,
    viewModel: EventDetailViewModel = hiltViewModel()
) {
    val rsvps by viewModel.rsvps.collectAsStateWithLifecycle()
    var declaredWeight by remember { mutableStateOf("") }

    Column(modifier.fillMaxSize().background(MarchColors.BackgroundGradient).padding(16.dp)) {
        Text(event.title, style = MaterialTheme.typography.headlineSmall, color = MarchColors.TextPrimary)
        event.description?.let { Text(it, color = MarchColors.TextSecondary, modifier = Modifier.padding(top = 4.dp)) }
        Text(event.startTime, color = MarchColors.Primary, modifier = Modifier.padding(top = 8.dp))
        event.addressText?.let { Text(it, color = MarchColors.TextSecondary) }
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(
            declaredWeight,
            { declaredWeight = it.filter { ch -> ch.isDigit() } },
            label = { Text("Declared weight (lbs)") },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))
        Button(onClick = { viewModel.rsvp(event.id, "going", declaredWeight.toIntOrNull()) }, modifier = Modifier.fillMaxWidth()) { Text("Going") }
        OutlinedButton(onClick = { viewModel.rsvp(event.id, "maybe", null) }, modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) { Text("Maybe") }
        OutlinedButton(onClick = { viewModel.rsvp(event.id, "out", null) }, modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) { Text("Out") }
        Spacer(Modifier.height(16.dp))
        Text("Attendees", color = MarchColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
        LazyColumn {
            items(rsvps) { rsvp ->
                Text("${rsvp.username ?: "Member"} — ${rsvp.status}", color = MarchColors.TextSecondary, modifier = Modifier.padding(vertical = 2.dp))
            }
        }
    }
}
