package com.artless.rucktracker.ui.tribe

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.data.model.EmergencyContact
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchInlineMessage
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchTextField
import com.artless.rucktracker.ui.components.marchPressable
import com.artless.rucktracker.ui.components.tabBarBottomInset
import com.artless.rucktracker.ui.theme.MarchColors
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Matches iOS WaiverOnboardingSheet: Safety Briefing → Emergency Contact → Digital Signature.
 * Membership is already inserted before this sheet is shown; signing updates club_members.
 */
@Composable
fun WaiverOnboardingSheet(
    clubName: String,
    isSubmitting: Boolean,
    error: String?,
    onSign: (EmergencyContact) -> Unit,
    onDismiss: () -> Unit
) {
    var step by remember { mutableIntStateOf(0) }
    var contactName by remember { mutableStateOf("") }
    var contactPhone by remember { mutableStateOf("") }
    var hasSigned by remember { mutableStateOf(false) }
    var hasScrolledToBottom by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MarchColors.Background)
            .statusBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(top = 16.dp, bottom = tabBarBottomInset())
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (step > 0) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                    contentDescription = "Back",
                    tint = MarchColors.Primary,
                    modifier = Modifier
                        .size(28.dp)
                        .marchPressable(onClick = { step -= 1 })
                )
            } else {
                Spacer(Modifier.width(28.dp))
            }
            Text(
                text = "Safety Waiver",
                style = MaterialTheme.typography.titleMedium,
                color = MarchColors.TextPrimary
            )
            Text(
                text = "Cancel",
                style = MaterialTheme.typography.labelLarge,
                color = MarchColors.TextSecondary,
                modifier = Modifier.marchPressable(onClick = onDismiss)
            )
        }

        Spacer(Modifier.height(16.dp))
        WaiverProgressBar(currentStep = step, totalSteps = 3)
        Spacer(Modifier.height(20.dp))

        when (step) {
            0 -> SafetyBriefingStep(
                clubName = clubName,
                hasScrolledToBottom = hasScrolledToBottom,
                onScrolledToBottom = { hasScrolledToBottom = true },
                onContinue = { step = 1 }
            )
            1 -> EmergencyContactStep(
                contactName = contactName,
                contactPhone = contactPhone,
                onNameChange = { contactName = it },
                onPhoneChange = { contactPhone = it },
                onContinue = { step = 2 }
            )
            else -> SignatureStep(
                hasSigned = hasSigned,
                isSubmitting = isSubmitting,
                error = error,
                onToggleSign = { hasSigned = !hasSigned },
                onSubmit = {
                    onSign(
                        EmergencyContact(
                            name = contactName.trim(),
                            phone = contactPhone.trim()
                        )
                    )
                }
            )
        }
    }
}

@Composable
private fun WaiverProgressBar(currentStep: Int, totalSteps: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        repeat(totalSteps) { index ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(
                        if (index <= currentStep) MarchColors.Primary else MarchColors.Surface
                    )
            )
        }
    }
}

@Composable
private fun SafetyBriefingStep(
    clubName: String,
    hasScrolledToBottom: Boolean,
    onScrolledToBottom: () -> Unit,
    onContinue: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        StepHeader(
            icon = Icons.Filled.Shield,
            title = "Safety Briefing",
            subtitle = "Please read the following carefully"
        )
        Spacer(Modifier.height(16.dp))

        val scrollState = rememberScrollState()
        LaunchedEffect(scrollState) {
            snapshotFlow {
                val max = scrollState.maxValue
                max == 0 || scrollState.value >= max - 24
            }
                .distinctUntilChanged()
                .collect { atBottom ->
                    if (atBottom) onScrolledToBottom()
                }
        }

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MarchColors.Surface)
                .border(1.dp, MarchColors.HairlineLight, RoundedCornerShape(16.dp))
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                SafetySection(
                    title = "Physical Activity Warning",
                    content = """
                        Rucking is a physically demanding activity. By participating in club events, you acknowledge that you are voluntarily engaging in physical exercise that may result in injury.

                        Before participating, ensure you:
                        • Have consulted with a physician if you have any health concerns
                        • Are properly hydrated and nourished
                        • Have appropriate footwear and equipment
                        • Know your physical limits
                    """.trimIndent()
                )
                SafetySection(
                    title = "Assumption of Risk",
                    content = """
                        You understand and accept that:
                        • Outdoor activities carry inherent risks including but not limited to: uneven terrain, weather conditions, traffic, and wildlife
                        • Club leaders are volunteers, not professional trainers
                        • You are responsible for your own safety and well-being
                        • You will follow the directions of club leaders
                    """.trimIndent()
                )
                SafetySection(
                    title = "Release of Liability",
                    content = """
                        By signing this waiver, you release and hold harmless $clubName, its founders, leaders, members, and affiliates from any claims, damages, or injuries arising from your participation in club activities.

                        This release applies to all club events, training sessions, and related activities.
                    """.trimIndent()
                )
                SafetySection(
                    title = "Emergency Procedures",
                    content = """
                        In case of emergency:
                        • Alert the nearest club leader immediately
                        • Call 911 if necessary
                        • Your emergency contact will be notified

                        By providing emergency contact information, you authorize club leaders to contact them in case of emergency.
                    """.trimIndent()
                )
            }
        }

        Spacer(Modifier.height(16.dp))
        MarchPrimaryButton(
            text = if (hasScrolledToBottom) "I've Read This" else "Scroll to Continue",
            onClick = onContinue,
            enabled = hasScrolledToBottom,
            height = 50.dp
        )
    }
}

@Composable
private fun SafetySection(title: String, content: String) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title.uppercase(),
            style = MaterialTheme.typography.labelMedium,
            color = MarchColors.Primary
        )
        Text(
            text = content,
            style = MaterialTheme.typography.bodyMedium,
            color = MarchColors.TextPrimary
        )
    }
}

@Composable
private fun EmergencyContactStep(
    contactName: String,
    contactPhone: String,
    onNameChange: (String) -> Unit,
    onPhoneChange: (String) -> Unit,
    onContinue: () -> Unit
) {
    val valid = contactName.isNotBlank() && contactPhone.isNotBlank()
    Column(modifier = Modifier.fillMaxSize()) {
        StepHeader(
            icon = Icons.Filled.Phone,
            title = "Emergency Contact",
            subtitle = "Who should we contact in an emergency?"
        )
        Spacer(Modifier.height(20.dp))
        MarchCard(contentPadding = 18.dp) {
            MarchTextField(
                value = contactName,
                onValueChange = onNameChange,
                label = "Contact name"
            )
            Spacer(Modifier.height(12.dp))
            MarchTextField(
                value = contactPhone,
                onValueChange = onPhoneChange,
                label = "Phone number",
                keyboardType = KeyboardType.Phone
            )
        }
        Spacer(Modifier.weight(1f))
        MarchPrimaryButton(
            text = "Continue",
            onClick = onContinue,
            enabled = valid,
            height = 50.dp
        )
    }
}

@Composable
private fun SignatureStep(
    hasSigned: Boolean,
    isSubmitting: Boolean,
    error: String?,
    onToggleSign: () -> Unit,
    onSubmit: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        StepHeader(
            icon = Icons.Filled.TouchApp,
            title = "Digital Signature",
            subtitle = "Tap to acknowledge and sign"
        )
        Spacer(Modifier.height(20.dp))

        MarchCard(contentPadding = 18.dp) {
            Text(
                text = "By signing, I acknowledge that:",
                style = MaterialTheme.typography.titleSmall,
                color = MarchColors.TextPrimary
            )
            Spacer(Modifier.height(12.dp))
            ChecklistItem("I have read and understood the safety briefing")
            ChecklistItem("I accept the risks associated with rucking")
            ChecklistItem("I release the club from liability")
            ChecklistItem("I authorize emergency contact notification")
        }

        Spacer(Modifier.height(16.dp))

        val borderColor = if (hasSigned) MarchColors.SuccessGreen else MarchColors.TextSecondary
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .border(2.dp, borderColor, RoundedCornerShape(16.dp))
                .background(
                    if (hasSigned) MarchColors.SuccessGreen.copy(alpha = 0.12f) else MarchColors.Surface
                )
                .marchPressable(onClick = onToggleSign)
                .padding(vertical = 32.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = if (hasSigned) Icons.Filled.CheckCircle else Icons.Filled.TouchApp,
                    contentDescription = null,
                    tint = if (hasSigned) MarchColors.SuccessGreen else MarchColors.TextSecondary,
                    modifier = Modifier.size(48.dp)
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    text = if (hasSigned) "Signed" else "Tap to Sign",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (hasSigned) MarchColors.SuccessGreen else MarchColors.TextSecondary
                )
            }
        }

        error?.let {
            Spacer(Modifier.height(12.dp))
            MarchInlineMessage(text = it)
        }

        Spacer(Modifier.weight(1f))
        MarchPrimaryButton(
            text = "Complete & Join Club",
            onClick = onSubmit,
            enabled = hasSigned,
            loading = isSubmitting,
            height = 50.dp
        )
    }
}

@Composable
private fun ChecklistItem(text: String) {
    Row(
        modifier = Modifier.padding(vertical = 4.dp),
        verticalAlignment = Alignment.Top
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = MarchColors.Primary,
            modifier = Modifier.size(18.dp)
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MarchColors.TextPrimary
        )
    }
}

@Composable
private fun StepHeader(icon: ImageVector, title: String, subtitle: String) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MarchColors.Primary,
            modifier = Modifier.size(48.dp)
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            color = MarchColors.TextPrimary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = MarchColors.TextSecondary,
            textAlign = TextAlign.Center
        )
    }
}
