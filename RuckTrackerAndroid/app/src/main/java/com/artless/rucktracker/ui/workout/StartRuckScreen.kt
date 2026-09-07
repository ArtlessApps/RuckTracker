package com.artless.rucktracker.ui.workout

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchChip
import com.artless.rucktracker.ui.components.MarchFieldLabel
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchIconButton
import com.artless.rucktracker.ui.components.MarchInlineMessage
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.components.MarchTextField
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens

private val LoadPresets = listOf(10, 20, 30, 45)

@Composable
fun StartRuckScreen(viewModel: WorkoutViewModel, onStarted: () -> Unit, onBack: () -> Unit) {
    val context = LocalContext.current
    var bodyWeightText by remember { mutableStateOf("") }
    var ruckWeightText by remember { mutableStateOf("") }
    var permissionDenied by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val (body, ruck) = viewModel.loadDefaults()
        bodyWeightText = body.toString()
        ruckWeightText = ruck.toString()
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) startWorkout(viewModel, bodyWeightText, ruckWeightText, onStarted)
        else permissionDenied = true
    }

    MarchBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(top = 12.dp, bottom = 24.dp)
        ) {
            MarchIconButton(
                icon = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                onClick = onBack,
                contentDescription = "Back"
            )

            Spacer(Modifier.height(20.dp))

            MarchScreenHeader(
                eyebrow = "New session",
                title = "Start a Ruck",
                subtitle = "Confirm your load and we'll start tracking."
            )

            Spacer(Modifier.height(MarchDimens.SectionGap))

            MarchCard(contentPadding = 20.dp) {
                MarchTextField(
                    value = bodyWeightText,
                    onValueChange = { bodyWeightText = it },
                    label = "Body weight",
                    keyboardType = KeyboardType.Decimal,
                    leadingIcon = Icons.AutoMirrored.Filled.DirectionsWalk,
                    suffix = "lb"
                )
                Spacer(Modifier.height(16.dp))
                MarchTextField(
                    value = ruckWeightText,
                    onValueChange = { ruckWeightText = it },
                    label = "Ruck weight",
                    keyboardType = KeyboardType.Decimal,
                    leadingIcon = Icons.Filled.Terrain,
                    suffix = "lb"
                )
                Spacer(Modifier.height(18.dp))
                MarchFieldLabel("Quick load")
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    LoadPresets.forEach { preset ->
                        MarchChip(
                            label = "$preset lb",
                            selected = ruckWeightText.toDoubleOrNull()?.toInt() == preset,
                            onClick = { ruckWeightText = preset.toString() }
                        )
                    }
                }
            }

            if (permissionDenied) {
                Spacer(Modifier.height(16.dp))
                MarchInlineMessage(
                    text = "Location permission is required to track distance and elevation."
                )
            }

            Spacer(Modifier.weight(1f))

            MarchPrimaryButton(
                text = "Begin Ruck",
                onClick = {
                    val granted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) startWorkout(viewModel, bodyWeightText, ruckWeightText, onStarted)
                    else permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                }
            )
            Spacer(Modifier.height(10.dp))
            MarchGhostButton(
                text = "Cancel",
                accent = MarchColors.TextSecondary,
                onClick = onBack,
                modifier = Modifier.navigationBarsPadding()
            )
        }
    }
}

private fun startWorkout(
    viewModel: WorkoutViewModel,
    bodyText: String,
    ruckText: String,
    onStarted: () -> Unit
) {
    viewModel.start(bodyText.toDoubleOrNull() ?: 180.0, ruckText.toDoubleOrNull() ?: 20.0)
    onStarted()
}
