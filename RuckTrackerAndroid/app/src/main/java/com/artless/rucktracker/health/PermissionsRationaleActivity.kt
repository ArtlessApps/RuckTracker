package com.artless.rucktracker.health

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchTheme

/**
 * Shown by Health Connect when the user taps the privacy policy link on the permission
 * screen, and from Settings > Apps > Permissions on Android 14+. Required for Health
 * Connect to display MARCH's permission request at all.
 */
class PermissionsRationaleActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MarchTheme {
                MarchBackground {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .statusBarsPadding()
                            .verticalScroll(rememberScrollState())
                            .padding(horizontal = MarchDimens.ScreenPadding)
                            .padding(top = 24.dp, bottom = 24.dp)
                    ) {
                        MarchScreenHeader(
                            eyebrow = "Health Connect",
                            title = "How MARCH uses heart rate",
                            subtitle = "Optional. MARCH works fully without it."
                        )
                        Spacer(Modifier.height(MarchDimens.SectionGap))
                        MarchCard(contentPadding = 20.dp) {
                            RationaleLines.forEachIndexed { index, line ->
                                if (index > 0) Spacer(Modifier.height(12.dp))
                                Text(
                                    text = line,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MarchColors.TextPrimary
                                )
                            }
                        }
                        Spacer(Modifier.height(MarchDimens.SectionGap))
                        MarchPrimaryButton(
                            text = "Read full privacy policy",
                            onClick = {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY_URL)))
                            }
                        )
                        Spacer(Modifier.height(10.dp))
                        MarchGhostButton(
                            text = "Close",
                            accent = MarchColors.TextSecondary,
                            onClick = { finish() },
                            modifier = Modifier.navigationBarsPadding()
                        )
                    }
                }
            }
        }
    }

    private companion object {
        const val PRIVACY_POLICY_URL = "https://marchrucking.com/privacy"

        val RationaleLines = listOf(
            "MARCH reads heart rate from Health Connect only while a ruck you started is in progress. It never reads your heart rate history or reads in the background.",
            "Your average heart rate is shown on the workout summary and included when you export your workouts to CSV, so you can see how hard each ruck was against your pack weight and pace.",
            "Heart rate is stored only on this device with your workout. It is not uploaded to our servers, shared with clubs or other users, sold, or used for advertising.",
            "MARCH does not write any data to Health Connect. You can revoke access at any time in the Health Connect app."
        )
    }
}
