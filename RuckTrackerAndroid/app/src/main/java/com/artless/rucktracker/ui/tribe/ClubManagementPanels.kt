package com.artless.rucktracker.ui.tribe

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.data.model.Club
import com.artless.rucktracker.data.model.ClubMember
import com.artless.rucktracker.data.model.ClubPost
import com.artless.rucktracker.data.model.ClubRole
import com.artless.rucktracker.data.model.EventRsvp
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchIconButton
import com.artless.rucktracker.ui.components.MarchInlineMessage
import com.artless.rucktracker.ui.components.MarchPill
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchSegmentedControl
import com.artless.rucktracker.ui.components.MarchTextField
import com.artless.rucktracker.ui.components.SectionHeader
import com.artless.rucktracker.ui.components.tabBarBottomInset
import com.artless.rucktracker.ui.components.tabBarContentPadding
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@Composable
fun ClubDetailHeader(
    club: Club,
    role: ClubRole,
    onBack: () -> Unit,
    onMembers: () -> Unit,
    onSettings: () -> Unit,
    onInvite: () -> Unit,
    onCopyCode: () -> Unit,
    onLeave: () -> Unit
) {
    var menuOpen by remember { mutableStateOf(false) }
    var confirmLeave by remember { mutableStateOf(false) }

    Row(verticalAlignment = Alignment.CenterVertically) {
        MarchIconButton(
            icon = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
            onClick = onBack,
            contentDescription = "Back to clubs"
        )
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = club.name,
                style = MaterialTheme.typography.headlineSmall,
                color = MarchColors.TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = "${club.memberCount} member${if (club.memberCount == 1) "" else "s"} · ${role.displayName}",
                style = MaterialTheme.typography.bodySmall,
                color = MarchColors.TextSecondary
            )
        }
        MarchIconButton(
            icon = Icons.Filled.Person,
            onClick = onMembers,
            contentDescription = "Members"
        )
        Spacer(Modifier.width(8.dp))
        Box {
            MarchIconButton(
                icon = Icons.Filled.MoreVert,
                onClick = { menuOpen = true },
                contentDescription = "Club menu"
            )
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                if (role.canEditClubDetails) {
                    DropdownMenuItem(
                        text = { Text("Club Settings") },
                        onClick = { menuOpen = false; onSettings() }
                    )
                }
                if (role.canInviteMembers) {
                    DropdownMenuItem(
                        text = { Text("Invite Members") },
                        onClick = { menuOpen = false; onInvite() }
                    )
                    DropdownMenuItem(
                        text = { Text("Copy Join Code") },
                        onClick = { menuOpen = false; onCopyCode() }
                    )
                }
                if (role.canLeaveClub) {
                    DropdownMenuItem(
                        text = { Text("Leave Club", color = MarchColors.DestructiveRed) },
                        onClick = { menuOpen = false; confirmLeave = true }
                    )
                }
            }
        }
    }

    if (confirmLeave) {
        AlertDialog(
            onDismissRequest = { confirmLeave = false },
            title = { Text("Leave Club?") },
            text = { Text("You'll need a join code to get back into \"${club.name}\".") },
            confirmButton = {
                TextButton(onClick = { confirmLeave = false; onLeave() }) {
                    Text("Leave", color = MarchColors.DestructiveRed)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmLeave = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
fun ColumnScope.ClubMembersPanel(state: TribeUiState, viewModel: TribeViewModel) {
    val club = state.selectedClub ?: return
    var selectedMember by remember { mutableStateOf<ClubMember?>(null) }
    var confirmRemove by remember { mutableStateOf<ClubMember?>(null) }
    val context = LocalContext.current

    PanelHeader(title = "Members", onBack = viewModel::dismissOverlay)
    Spacer(Modifier.height(12.dp))

    MarchCard(contentPadding = 18.dp) {
        Text(
            text = "${state.members.size}",
            style = MaterialTheme.typography.displaySmall,
            color = MarchColors.Primary
        )
        Text("Members", color = MarchColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
        if (state.userRole.canInviteMembers) {
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                MarchPill(text = "Code ${club.joinCode}", accent = MarchColors.Primary)
                Spacer(Modifier.width(10.dp))
                MarchIconButton(
                    icon = Icons.Filled.Share,
                    onClick = { shareInvite(context, club) },
                    contentDescription = "Share invite",
                    size = 36.dp
                )
            }
        }
    }

    Spacer(Modifier.height(18.dp))

    LazyColumn(
        modifier = Modifier.weight(1f),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = tabBarContentPadding()
    ) {
        listOf(
            "Founders" to state.members.filter { it.clubRole == ClubRole.FOUNDER },
            "Leaders" to state.members.filter { it.clubRole == ClubRole.LEADER },
            "Members" to state.members.filter { it.clubRole == ClubRole.MEMBER }
        ).forEach { (title, members) ->
            if (members.isNotEmpty()) {
                item(key = "header-$title") {
                    SectionHeader(title)
                    Spacer(Modifier.height(8.dp))
                }
                items(members, key = { it.userId }) { member ->
                    MemberRow(
                        member = member,
                        onClick = {
                            if (member.clubRole != ClubRole.FOUNDER &&
                                (state.userRole.canManageMembers || state.userRole.canRemoveMembers)
                            ) {
                                selectedMember = member
                            }
                        }
                    )
                }
                item { Spacer(Modifier.height(8.dp)) }
            }
        }
    }

    selectedMember?.let { member ->
        AlertDialog(
            onDismissRequest = { selectedMember = null },
            title = { Text(member.username ?: "Member") },
            text = {
                Column {
                    Text(member.clubRole.displayName, color = MarchColors.TextSecondary)
                    Spacer(Modifier.height(12.dp))
                    if (state.userRole.canManageMembers && member.clubRole == ClubRole.MEMBER) {
                        MarchPrimaryButton(
                            text = "Promote to Leader",
                            onClick = {
                                viewModel.promoteMember(member.userId)
                                selectedMember = null
                            },
                            height = 46.dp
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                    if (state.userRole.canManageMembers && member.clubRole == ClubRole.LEADER) {
                        MarchPrimaryButton(
                            text = "Demote to Member",
                            onClick = {
                                viewModel.demoteMember(member.userId)
                                selectedMember = null
                            },
                            height = 46.dp
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                    if (state.userRole.canRemoveMembers) {
                        MarchGhostButton(
                            text = "Remove from Club",
                            accent = MarchColors.DestructiveRed,
                            onClick = {
                                selectedMember = null
                                confirmRemove = member
                            }
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { selectedMember = null }) { Text("Close") }
            }
        )
    }

    confirmRemove?.let { member ->
        AlertDialog(
            onDismissRequest = { confirmRemove = null },
            title = { Text("Remove Member") },
            text = { Text("Remove ${member.username ?: "this member"} from the club?") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.removeMember(member.userId)
                    confirmRemove = null
                }) { Text("Remove", color = MarchColors.DestructiveRed) }
            },
            dismissButton = {
                TextButton(onClick = { confirmRemove = null }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun MemberRow(member: ClubMember, onClick: () -> Unit) {
    MarchCard(onClick = onClick, contentPadding = 14.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(MarchColors.Primary.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = (member.username ?: "M").take(1).uppercase(),
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.Primary
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = member.username ?: "Member",
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.TextPrimary
                )
                Text(
                    text = member.clubRole.displayName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MarchColors.TextSecondary
                )
            }
        }
    }
}

@Composable
fun ColumnScope.ClubSettingsPanel(state: TribeUiState, viewModel: TribeViewModel) {
    val club = state.selectedClub ?: return
    var name by remember(club.id) { mutableStateOf(club.name) }
    var description by remember(club.id) { mutableStateOf(club.description.orEmpty()) }
    var zipcode by remember(club.id) { mutableStateOf(club.zipcode.orEmpty()) }
    var isPrivate by remember(club.id) { mutableStateOf(club.isPrivate) }
    var confirmDelete by remember { mutableStateOf(false) }
    var confirmRegen by remember { mutableStateOf(false) }
    var showTransfer by remember { mutableStateOf(false) }
    val context = LocalContext.current

    PanelHeader(title = "Club Settings", onBack = viewModel::dismissOverlay)
    Spacer(Modifier.height(12.dp))

    Column(
        modifier = Modifier
            .weight(1f)
            .verticalScroll(rememberScrollState())
    ) {
        state.error?.let {
            MarchInlineMessage(text = it)
            Spacer(Modifier.height(12.dp))
        }
        state.successMessage?.let {
            MarchInlineMessage(text = it)
            Spacer(Modifier.height(12.dp))
        }

        SectionHeader("Club Details")
        Spacer(Modifier.height(12.dp))
        MarchCard(contentPadding = 18.dp) {
            MarchTextField(value = name, onValueChange = { name = it }, label = "Club name")
            Spacer(Modifier.height(12.dp))
            MarchTextField(
                value = description,
                onValueChange = { description = it },
                label = "Description",
                singleLine = false
            )
            Spacer(Modifier.height(12.dp))
            MarchTextField(
                value = zipcode,
                onValueChange = { zipcode = it.filter(Char::isDigit).take(10) },
                label = "Location (zipcode)",
                keyboardType = KeyboardType.Number
            )
            Spacer(Modifier.height(14.dp))
            MarchSegmentedControl(
                options = listOf("Public", "Private"),
                selectedIndex = if (isPrivate) 1 else 0,
                onSelect = { isPrivate = it == 1 }
            )
            Spacer(Modifier.height(14.dp))
            MarchPrimaryButton(
                text = "Save Changes",
                loading = state.isSaving,
                enabled = name.isNotBlank(),
                onClick = { viewModel.saveClubSettings(name, description, isPrivate, zipcode) },
                height = 50.dp
            )
        }

        Spacer(Modifier.height(MarchDimens.SectionGap))
        SectionHeader("Invite")
        Spacer(Modifier.height(12.dp))
        MarchCard(contentPadding = 18.dp) {
            MarchPill(text = "Code ${club.joinCode}", accent = MarchColors.Primary)
            Spacer(Modifier.height(12.dp))
            MarchPrimaryButton(
                text = "Share Invite",
                onClick = { shareInvite(context, club) },
                height = 46.dp
            )
            Spacer(Modifier.height(8.dp))
            MarchGhostButton(
                text = "Regenerate Join Code",
                accent = MarchColors.AccentWarm,
                onClick = { confirmRegen = true }
            )
        }

        Spacer(Modifier.height(MarchDimens.SectionGap))
        SectionHeader("Danger Zone")
        Spacer(Modifier.height(12.dp))
        MarchCard(contentPadding = 18.dp) {
            MarchGhostButton(
                text = "Transfer Ownership",
                accent = MarchColors.AccentWarm,
                onClick = {
                    viewModel.loadMembers()
                    showTransfer = true
                }
            )
            Spacer(Modifier.height(8.dp))
            MarchGhostButton(
                text = "Delete Club",
                accent = MarchColors.DestructiveRed,
                onClick = { confirmDelete = true }
            )
        }
        Spacer(Modifier.height(tabBarBottomInset()))
    }

    if (confirmRegen) {
        AlertDialog(
            onDismissRequest = { confirmRegen = false },
            title = { Text("Regenerate Join Code") },
            text = { Text("The current code will stop working. Share the new code with your members.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmRegen = false
                    viewModel.regenerateJoinCode()
                }) { Text("Regenerate", color = MarchColors.AccentWarm) }
            },
            dismissButton = {
                TextButton(onClick = { confirmRegen = false }) { Text("Cancel") }
            }
        )
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete Club") },
            text = {
                Text("This permanently deletes \"${club.name}\" and all posts, events, and member history.")
            },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    viewModel.deleteClub()
                }) { Text("Delete Forever", color = MarchColors.DestructiveRed) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Cancel") }
            }
        )
    }

    if (showTransfer) {
        val candidates = state.members.filter { it.clubRole != ClubRole.FOUNDER }
        AlertDialog(
            onDismissRequest = { showTransfer = false },
            title = { Text("Transfer Ownership") },
            text = {
                Column {
                    Text("Pick a member to become the new founder. You'll become a leader.")
                    Spacer(Modifier.height(12.dp))
                    if (candidates.isEmpty()) {
                        Text("No other members yet.", color = MarchColors.TextSecondary)
                    } else {
                        candidates.forEach { member ->
                            MarchCard(
                                onClick = {
                                    showTransfer = false
                                    viewModel.transferOwnership(member.userId)
                                },
                                contentPadding = 12.dp,
                                modifier = Modifier.padding(vertical = 4.dp)
                            ) {
                                Text(member.username ?: "Member", color = MarchColors.TextPrimary)
                                Text(member.clubRole.displayName, color = MarchColors.TextSecondary)
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showTransfer = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
fun ColumnScope.CreateEventPanel(state: TribeUiState, viewModel: TribeViewModel) {
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var dateText by remember { mutableStateOf(LocalDate.now().plusDays(1).toString()) }
    var timeText by remember { mutableStateOf("07:00") }

    PanelHeader(title = "Create Event", onBack = viewModel::dismissOverlay)
    Spacer(Modifier.height(12.dp))

    Column(
        modifier = Modifier
            .weight(1f)
            .verticalScroll(rememberScrollState())
    ) {
        state.error?.let {
            MarchInlineMessage(text = it)
            Spacer(Modifier.height(12.dp))
        }
        MarchCard(contentPadding = 18.dp) {
            MarchTextField(value = title, onValueChange = { title = it }, label = "Title")
            Spacer(Modifier.height(12.dp))
            MarchTextField(
                value = description,
                onValueChange = { description = it },
                label = "Description (optional)",
                singleLine = false
            )
            Spacer(Modifier.height(12.dp))
            MarchTextField(
                value = dateText,
                onValueChange = { dateText = it },
                label = "Date (YYYY-MM-DD)"
            )
            Spacer(Modifier.height(12.dp))
            MarchTextField(
                value = timeText,
                onValueChange = { timeText = it },
                label = "Time (HH:MM, 24h)"
            )
            Spacer(Modifier.height(12.dp))
            MarchTextField(
                value = address,
                onValueChange = { address = it },
                label = "Meeting address (optional)"
            )
            Spacer(Modifier.height(14.dp))
            MarchPrimaryButton(
                text = "Create Event",
                enabled = title.isNotBlank() && dateText.isNotBlank() && timeText.isNotBlank(),
                loading = state.isSaving,
                onClick = {
                    val iso = runCatching {
                        val date = LocalDate.parse(dateText.trim())
                        val time = LocalTime.parse(timeText.trim())
                        val local = LocalDateTime.of(date, time)
                        local.atOffset(ZoneOffset.systemDefault().rules.getOffset(local))
                            .format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
                    }.getOrNull()
                    if (iso != null) {
                        viewModel.createEvent(title, description, iso, address)
                    } else {
                        viewModel.reportError("Use date YYYY-MM-DD and time HH:MM")
                    }
                },
                height = 50.dp
            )
        }
        Spacer(Modifier.height(tabBarBottomInset()))
    }
}

@Composable
fun ColumnScope.EventDetailPanel(state: TribeUiState, viewModel: TribeViewModel) {
    val event = state.selectedEvent ?: return
    var weight by remember { mutableStateOf("") }
    var comment by remember { mutableStateOf("") }
    var confirmDelete by remember { mutableStateOf(false) }

    PanelHeader(title = "Event", onBack = viewModel::dismissOverlay)
    Spacer(Modifier.height(12.dp))

    Column(
        modifier = Modifier
            .weight(1f)
            .verticalScroll(rememberScrollState())
    ) {
        MarchCard(contentPadding = 18.dp) {
            Text(event.title, style = MaterialTheme.typography.headlineSmall, color = MarchColors.TextPrimary)
            event.description?.takeIf { it.isNotBlank() }?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, color = MarchColors.TextSecondary)
            }
            Spacer(Modifier.height(10.dp))
            Text(
                event.startTime.take(16).replace('T', ' '),
                color = MarchColors.Primary,
                style = MaterialTheme.typography.bodyMedium
            )
            event.addressText?.takeIf { it.isNotBlank() }?.let {
                Spacer(Modifier.height(6.dp))
                Text(it, color = MarchColors.TextSecondary, style = MaterialTheme.typography.bodySmall)
            }
        }

        Spacer(Modifier.height(16.dp))
        SectionHeader("RSVP")
        Spacer(Modifier.height(12.dp))
        MarchCard(contentPadding = 18.dp) {
            MarchTextField(
                value = weight,
                onValueChange = { weight = it.filter { ch -> ch.isDigit() } },
                label = "Declared weight (lbs)",
                keyboardType = KeyboardType.Number
            )
            Spacer(Modifier.height(12.dp))
            MarchPrimaryButton(
                text = "I'm In",
                onClick = { viewModel.rsvpToEvent("going", weight.toIntOrNull()) },
                height = 46.dp
            )
            Spacer(Modifier.height(8.dp))
            MarchGhostButton(text = "Maybe", onClick = { viewModel.rsvpToEvent("maybe", null) })
            Spacer(Modifier.height(8.dp))
            MarchGhostButton(
                text = "Out",
                accent = MarchColors.TextSecondary,
                onClick = { viewModel.rsvpToEvent("out", null) }
            )
        }

        Spacer(Modifier.height(16.dp))
        SectionHeader("Attendees")
        Spacer(Modifier.height(12.dp))
        if (state.eventRsvps.isEmpty()) {
            Text("No RSVPs yet", color = MarchColors.TextSecondary)
        } else {
            state.eventRsvps.forEach { rsvp ->
                AttendeeRow(rsvp)
                Spacer(Modifier.height(8.dp))
            }
        }

        Spacer(Modifier.height(16.dp))
        SectionHeader("The Wire")
        Spacer(Modifier.height(12.dp))
        MarchCard(contentPadding = 18.dp) {
            if (state.eventComments.isEmpty()) {
                Text("No messages yet. Start the thread.", color = MarchColors.TextSecondary)
                Spacer(Modifier.height(12.dp))
            } else {
                state.eventComments.forEach { post ->
                    WireComment(post)
                    Spacer(Modifier.height(10.dp))
                }
            }
            MarchTextField(
                value = comment,
                onValueChange = { comment = it },
                label = "Message",
                singleLine = false
            )
            Spacer(Modifier.height(10.dp))
            MarchPrimaryButton(
                text = "Send",
                enabled = comment.isNotBlank(),
                onClick = {
                    viewModel.postEventComment(comment)
                    comment = ""
                },
                height = 46.dp
            )
        }

        if (state.userRole.canCreateEvents) {
            Spacer(Modifier.height(16.dp))
            MarchGhostButton(
                text = "Delete Event",
                accent = MarchColors.DestructiveRed,
                onClick = { confirmDelete = true }
            )
        }
        Spacer(Modifier.height(tabBarBottomInset()))
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete Event") },
            text = { Text("Delete \"${event.title}\"? This can't be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    viewModel.deleteEvent()
                }) { Text("Delete", color = MarchColors.DestructiveRed) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun AttendeeRow(rsvp: EventRsvp) {
    MarchCard(contentPadding = 12.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = rsvp.username ?: "Member",
                color = MarchColors.TextPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = rsvp.status.replaceFirstChar { it.uppercase() },
                color = MarchColors.Primary,
                style = MaterialTheme.typography.labelLarge
            )
            rsvp.declaredWeight?.let {
                Text(" · $it lb", color = MarchColors.TextSecondary)
            }
        }
    }
}

@Composable
private fun WireComment(post: ClubPost) {
    Column {
        Text(
            text = post.username ?: "Member",
            style = MaterialTheme.typography.titleSmall,
            color = MarchColors.Primary
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = post.content.orEmpty(),
            style = MaterialTheme.typography.bodyMedium,
            color = MarchColors.TextPrimary
        )
    }
}

@Composable
private fun PanelHeader(title: String, onBack: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        MarchIconButton(
            icon = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
            onClick = onBack,
            contentDescription = "Back"
        )
        Spacer(Modifier.width(14.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            color = MarchColors.TextPrimary
        )
    }
}

fun copyJoinCode(context: Context, code: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Join code", code))
}

fun shareInvite(context: Context, club: Club) {
    val message = "Join my MARCH club \"${club.name}\" with code ${club.joinCode}"
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, message)
    }
    context.startActivity(Intent.createChooser(intent, "Invite to ${club.name}"))
}
