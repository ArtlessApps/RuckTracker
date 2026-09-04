package com.artless.rucktracker.ui.tribe

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.data.model.EmergencyContact
import com.artless.rucktracker.ui.theme.MarchColors

@Composable
fun WaiverOnboardingSheet(
    clubName: String,
    onSign: (EmergencyContact) -> Unit,
    onDismiss: () -> Unit
) {
    var step by remember { mutableStateOf(0) }
    var contactName by remember { mutableStateOf("") }
    var contactPhone by remember { mutableStateOf("") }
    var signatureConfirmed by remember { mutableStateOf(false) }

    Column(Modifier.background(MarchColors.Surface).padding(24.dp)) {
        when (step) {
            0 -> {
                Text("Safety Briefing", style = MaterialTheme.typography.titleLarge, color = MarchColors.TextPrimary)
                Text("Rucking involves physical exertion under load. Know your limits.", color = MarchColors.TextSecondary, modifier = Modifier.padding(top = 8.dp))
                Button(onClick = { step = 1 }, modifier = Modifier.fillMaxWidth().padding(top = 16.dp)) { Text("Continue") }
            }
            1 -> {
                Text("Emergency Contact", style = MaterialTheme.typography.titleLarge, color = MarchColors.TextPrimary)
                OutlinedTextField(contactName, { contactName = it }, label = { Text("Contact name") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(contactPhone, { contactPhone = it }, label = { Text("Phone") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
                Button(onClick = { step = 2 }, enabled = contactName.isNotBlank() && contactPhone.isNotBlank(), modifier = Modifier.fillMaxWidth().padding(top = 16.dp)) { Text("Continue") }
            }
            2 -> {
                Text("Waiver for $clubName", style = MaterialTheme.typography.titleLarge, color = MarchColors.TextPrimary)
                Text("I acknowledge the risks of rucking and release the club from liability.", color = MarchColors.TextSecondary, modifier = Modifier.padding(top = 8.dp))
                Button(onClick = { signatureConfirmed = true }, modifier = Modifier.fillMaxWidth().padding(top = 16.dp)) { Text("I Agree") }
                if (signatureConfirmed) {
                    Button(onClick = {
                        onSign(EmergencyContact(contactName, contactPhone))
                    }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) { Text("Sign & Join") }
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Button(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("Cancel") }
    }
}
