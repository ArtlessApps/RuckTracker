package com.artless.rucktracker.ui.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchInlineMessage
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchTextField
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType

@Composable
fun AuthScreen(viewModel: AuthViewModel = viewModel()) {
    var isSignUpMode by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    val isSubmitting by viewModel.isSubmitting.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val infoMessage by viewModel.infoMessage.collectAsState()

    val canSubmit = !isSubmitting &&
        email.isNotBlank() &&
        password.isNotBlank() &&
        (!isSignUpMode || username.isNotBlank())

    MarchBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                // Keeps the submit button reachable while the keyboard is up.
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(vertical = 32.dp),
            // Centres the sign-in stack on tall screens; becomes a no-op once
            // the keyboard is up and the content outgrows the viewport.
            verticalArrangement = Arrangement.Center
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "MARCH",
                    style = MarchType.Wordmark,
                    color = MarchColors.TextPrimary
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "WALK STRONGER",
                    style = MarchType.Eyebrow.copy(letterSpacing = 4.sp),
                    color = MarchColors.Primary
                )
                Spacer(Modifier.height(20.dp))
                Text(
                    text = if (isSignUpMode) {
                        "Create your account to track every ruck."
                    } else {
                        "Welcome back. Time to move some weight."
                    },
                    style = MaterialTheme.typography.bodyLarge,
                    color = MarchColors.TextSecondary,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(Modifier.height(44.dp))

            MarchTextField(
                value = email,
                onValueChange = { email = it },
                label = "Email",
                keyboardType = KeyboardType.Email,
                leadingIcon = Icons.Filled.Email
            )

            if (isSignUpMode) {
                Spacer(Modifier.height(14.dp))
                MarchTextField(
                    value = username,
                    onValueChange = { username = it },
                    label = "Username",
                    leadingIcon = Icons.Filled.Person
                )
            }

            Spacer(Modifier.height(14.dp))
            MarchTextField(
                value = password,
                onValueChange = { password = it },
                label = "Password",
                keyboardType = KeyboardType.Password,
                visualTransformation = PasswordVisualTransformation(),
                leadingIcon = Icons.Filled.Lock
            )

            errorMessage?.let {
                Spacer(Modifier.height(16.dp))
                MarchInlineMessage(text = it)
            }
            infoMessage?.let {
                Spacer(Modifier.height(16.dp))
                MarchInlineMessage(text = it, accent = MarchColors.Primary)
            }

            Spacer(Modifier.height(28.dp))

            MarchPrimaryButton(
                text = if (isSignUpMode) "Create Account" else "Sign In",
                onClick = {
                    if (isSignUpMode) viewModel.signUp(email, username, password)
                    else viewModel.signIn(email, password)
                },
                enabled = canSubmit,
                loading = isSubmitting
            )

            Spacer(Modifier.height(12.dp))

            MarchGhostButton(
                text = if (isSignUpMode) "I already have an account" else "New here? Create an account",
                accent = MarchColors.TextSecondary,
                onClick = { isSignUpMode = !isSignUpMode },
                modifier = Modifier.navigationBarsPadding()
            )
        }
    }
}
