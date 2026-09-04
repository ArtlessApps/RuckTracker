package com.artless.rucktracker.ui.tribe

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.model.Club
import com.artless.rucktracker.data.model.ClubEvent
import com.artless.rucktracker.data.model.ClubPost
import com.artless.rucktracker.data.model.LeaderboardEntry
import com.artless.rucktracker.ui.components.CircleIcon
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchEmptyState
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchIconButton
import com.artless.rucktracker.ui.components.MarchInlineMessage
import com.artless.rucktracker.ui.components.MarchPill
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchScreen
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.components.MarchSegmentedControl
import com.artless.rucktracker.ui.components.MarchTextField
import com.artless.rucktracker.ui.components.RankMedallion
import com.artless.rucktracker.ui.components.SectionHeader
import com.artless.rucktracker.ui.components.marchPressable
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import java.util.Locale

@Composable
fun TribeScreen(modifier: Modifier = Modifier, viewModel: TribeViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    MarchScreen(modifier = modifier) {
        when {
            !state.isAuthenticated -> {
                MarchScreenHeader(eyebrow = "Community", title = "Tribe")
                MarchEmptyState(
                    icon = Icons.Filled.Groups,
                    title = "Rucking is better together",
                    message = "Sign in to join a club, share your rucks and climb your tribe's leaderboard.",
                    accent = MarchColors.TileGold,
                    actionLabel = "Sign In",
                    onAction = viewModel::promptSignIn,
                    modifier = Modifier.weight(1f)
                )
            }

            state.selectedClub == null -> {
                MarchScreenHeader(eyebrow = "Community", title = "Tribe")
                Spacer(Modifier.height(20.dp))
                ClubDiscovery(state = state, viewModel = viewModel)
            }

            else -> ClubDetail(state = state, viewModel = viewModel)
        }
    }
}

@Composable
private fun ColumnScope.ClubDiscovery(state: TribeUiState, viewModel: TribeViewModel) {
    var joinCode by remember { mutableStateOf("") }
    var showCreate by remember { mutableStateOf(false) }
    var clubName by remember { mutableStateOf("") }
    var clubDescription by remember { mutableStateOf("") }
    var isPrivate by remember { mutableStateOf(false) }
    var zipcode by remember { mutableStateOf("") }
    var customInviteCode by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .weight(1f)
            .verticalScroll(rememberScrollState())
    ) {
        if (state.clubs.isEmpty()) {
            MarchEmptyState(
                icon = Icons.Filled.Groups,
                title = "No club yet",
                message = "Join with a code from a friend, or start your own and invite your crew.",
                accent = MarchColors.TileGold
            )
        } else {
            SectionHeader("Your clubs")
            Spacer(Modifier.height(12.dp))
            state.clubs.forEach { club ->
                ClubCard(club = club, onClick = { viewModel.selectClub(club) })
                Spacer(Modifier.height(10.dp))
            }
            Spacer(Modifier.height(MarchDimens.SectionGap - MarchDimens.CardGap))
        }

        SectionHeader("Join a club")
        Spacer(Modifier.height(12.dp))
        MarchCard(contentPadding = 18.dp) {
            MarchTextField(
                value = joinCode,
                onValueChange = { joinCode = it },
                label = "Join code"
            )
            Spacer(Modifier.height(14.dp))
            MarchPrimaryButton(
                text = "Join Club",
                onClick = { viewModel.joinClub(joinCode) },
                enabled = joinCode.isNotBlank(),
                height = 50.dp
            )
        }

        Spacer(Modifier.height(MarchDimens.SectionGap))

        if (showCreate) {
            SectionHeader("Create a club")
            Spacer(Modifier.height(12.dp))
            MarchCard(contentPadding = 18.dp) {
                MarchTextField(
                    value = clubName,
                    onValueChange = { clubName = it },
                    label = "Club name"
                )
                Spacer(Modifier.height(12.dp))
                MarchTextField(
                    value = clubDescription,
                    onValueChange = { clubDescription = it },
                    label = "Description (optional)",
                    singleLine = false
                )
                Spacer(modifier.height(16.dp))
                Text(
                    text = "Visibility",
                    style = MaterialTheme.typography.labelLarge,
                    color = MarchColors.TextSecondary
                )
                Spacer(modifier.height(8.dp))
                MarchSegmentedControl(
                    options = listOf("Public", "Private"),
                    selectedIndex = if (isPrivate) 1 else 0,
                    onSelect = { isPrivate = it == 1 }
                )
                Spacer(modifier.height(6.dp))
                Text(
                    text = if (isPrivate) {
                        "Only visible with invite code"
                    } else {
                        "Visible in club search"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MarchColors.TextSecondary
                )
                if (isPrivate) {
                    Spacer(modifier.height(12.dp))
                    MarchTextField(
                        value = customInviteCode,
                        onValueChange = { customInviteCode = it.uppercase() },
                        label = "Custom invite code (optional)"
                    )
                    Spacer(modifier.height(6.dp))
                    Text(
                        text = "Leave blank to auto-generate. Custom codes must be unique.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MarchColors.TextSecondary
                    )
                }
                Spacer(modifier.height(12.dp))
                MarchTextField(
                    value = zipcode,
                    onValueChange = { zipcode = it.filter { ch -> ch.isDigit() }.take(10) },
                    label = "Location (zipcode)",
                    keyboardType = KeyboardType.Number,
                    leadingIcon = Icons.Filled.LocationOn
                )
                Spacer(modifier.height(6.dp))
                Text(
                    text = "Helps nearby ruckers find your club",
                    style = MaterialTheme.typography.bodySmall,
                    color = MarchColors.TextSecondary
                )
                Spacer(modifier.height(14.dp))
                MarchPrimaryButton(
                    text = "Create Club",
                    onClick = {
                        viewModel.createClub(
                            name = clubName,
                            description = clubDescription,
                            isPrivate = isPrivate,
                            zipcode = zipcode,
                            customJoinCode = customInviteCode.takeIf { isPrivate && it.isNotBlank() }
                        )
                    },
                    enabled = clubName.isNotBlank(),
                    height = 50.dp
                )
            }
            Spacer(Modifier.height(10.dp))
        }

        MarchGhostButton(
            text = if (showCreate) "Cancel" else "Create a Club",
            accent = if (showCreate) MarchColors.TextSecondary else MarchColors.Primary,
            onClick = {
                showCreate = !showCreate
                if (!showCreate) {
                    clubName = ""
                    clubDescription = ""
                    isPrivate = false
                    zipcode = ""
                    customInviteCode = ""
                }
            }
        )

        state.error?.let {
            Spacer(Modifier.height(14.dp))
            MarchInlineMessage(text = it)
        }

        Spacer(Modifier.height(MarchDimens.TabBarClearance))
    }
}

@Composable
private fun ColumnScope.ClubDetail(state: TribeUiState, viewModel: TribeViewModel) {
    val club = state.selectedClub ?: return
    var tab by remember { mutableIntStateOf(0) }

    Row(verticalAlignment = Alignment.CenterVertically) {
        MarchIconButton(
            icon = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
            onClick = viewModel::clearSelectedClub,
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
                text = "${club.memberCount} member${if (club.memberCount == 1) "" else "s"}",
                style = MaterialTheme.typography.bodySmall,
                color = MarchColors.TextSecondary
            )
        }
    }

    Spacer(Modifier.height(16.dp))

    MarchPill(text = "Code ${club.joinCode}", accent = MarchColors.Primary)

    Spacer(Modifier.height(18.dp))

    MarchSegmentedControl(
        options = listOf("Feed", "Board", "Events"),
        selectedIndex = tab,
        onSelect = { tab = it }
    )

    Spacer(Modifier.height(16.dp))

    val listModifier = Modifier.weight(1f)
    when (tab) {
        0 -> FeedTab(state.feedPosts, viewModel::toggleLike, listModifier)
        1 -> ClubLeaderboardTab(state.leaderboard, listModifier)
        else -> EventsTab(state.events, listModifier)
    }
}

@Composable
private fun ClubCard(club: Club, onClick: () -> Unit) {
    MarchCard(onClick = onClick, contentPadding = 16.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CircleIcon(
                icon = Icons.AutoMirrored.Filled.DirectionsWalk,
                accent = MarchColors.TileGold,
                size = 46.dp,
                iconSize = 21.dp
            )
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = club.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "${club.memberCount} member${if (club.memberCount == 1) "" else "s"}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MarchColors.TextSecondary
                )
            }
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MarchColors.TextSecondary,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}

@Composable
private fun FeedTab(
    posts: List<ClubPost>,
    onLike: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (posts.isEmpty()) {
        MarchEmptyState(
            icon = Icons.AutoMirrored.Filled.DirectionsWalk,
            title = "Quiet in here",
            message = "Finish a ruck and it will show up in your club feed.",
            modifier = modifier
        )
        return
    }

    LazyColumn(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(bottom = MarchDimens.TabBarClearance)
    ) {
        items(posts, key = { it.id }) { post ->
            FeedPostCard(post = post, onLike = { onLike(post.id) })
        }
    }
}

@Composable
private fun FeedPostCard(post: ClubPost, onLike: () -> Unit) {
    MarchCard(contentPadding = 16.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(MarchColors.Primary.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = (post.username ?: "M").take(1).uppercase(),
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.Primary
                )
            }
            Spacer(Modifier.width(12.dp))
            Text(
                text = post.username ?: "Member",
                style = MaterialTheme.typography.titleSmall,
                color = MarchColors.TextPrimary,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            LikeButton(count = post.likeCount, liked = post.isLiked, onClick = onLike)
        }

        if (post.distanceMiles != null || post.weightLbs != null) {
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                post.distanceMiles?.let {
                    MetricChip(String.format(Locale.US, "%.2f mi", it))
                }
                post.weightLbs?.let {
                    MetricChip("${it.toInt()} lb")
                }
                post.elevationGain?.takeIf { it > 0 }?.let {
                    MetricChip("${it.toInt()} ft")
                }
            }
        }

        post.content?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(12.dp))
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = MarchColors.TextSecondary
            )
        }
    }
}

@Composable
private fun LikeButton(count: Int, liked: Boolean, onClick: () -> Unit) {
    val accent = if (liked) MarchColors.DestructiveRed else MarchColors.TextSecondary
    Row(
        modifier = Modifier
            .marchPressable(onClick = onClick, pressedScale = 0.9f)
            .clip(CircleShape)
            .background(accent.copy(alpha = 0.12f))
            .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (liked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
            contentDescription = "Like",
            tint = accent,
            modifier = Modifier.size(15.dp)
        )
        if (count > 0) {
            Spacer(Modifier.width(6.dp))
            Text(
                text = count.toString(),
                style = MaterialTheme.typography.labelLarge,
                color = accent
            )
        }
    }
}

@Composable
private fun ClubLeaderboardTab(entries: List<LeaderboardEntry>, modifier: Modifier = Modifier) {
    if (entries.isEmpty()) {
        MarchEmptyState(
            icon = Icons.Filled.Groups,
            title = "No standings yet",
            message = "Once members log rucks, your club board fills in here.",
            modifier = modifier
        )
        return
    }

    LazyColumn(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(bottom = MarchDimens.TabBarClearance)
    ) {
        items(entries, key = { it.userId }) { entry ->
            MarchCard(contentPadding = 14.dp) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RankMedallion(rank = entry.rank, size = 38.dp)
                    Spacer(Modifier.width(14.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = entry.username ?: "Member",
                            style = MaterialTheme.typography.titleMedium,
                            color = MarchColors.TextPrimary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = "${entry.totalWorkouts} ruck${if (entry.totalWorkouts == 1) "" else "s"}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MarchColors.TextSecondary
                        )
                    }
                    Text(
                        text = String.format(Locale.US, "%.1f mi", entry.totalDistance),
                        style = MaterialTheme.typography.titleMedium,
                        color = MarchColors.Primary
                    )
                }
            }
        }
    }
}

@Composable
private fun EventsTab(events: List<ClubEvent>, modifier: Modifier = Modifier) {
    if (events.isEmpty()) {
        MarchEmptyState(
            icon = Icons.Filled.CalendarMonth,
            title = "No events scheduled",
            message = "Club events and group rucks will appear here.",
            accent = MarchColors.TileBlue,
            modifier = modifier
        )
        return
    }

    LazyColumn(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(bottom = MarchDimens.TabBarClearance)
    ) {
        items(events, key = { it.id }) { event ->
            MarchCard(contentPadding = 16.dp) {
                Row(verticalAlignment = Alignment.Top) {
                    CircleIcon(
                        icon = Icons.Filled.CalendarMonth,
                        accent = MarchColors.TileBlue,
                        size = 42.dp,
                        iconSize = 19.dp
                    )
                    Spacer(Modifier.width(14.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = event.title,
                            style = MaterialTheme.typography.titleMedium,
                            color = MarchColors.TextPrimary
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = event.startTime.take(16).replace('T', ' '),
                            style = MaterialTheme.typography.bodySmall,
                            color = MarchColors.Primary
                        )
                        event.addressText?.takeIf { it.isNotBlank() }?.let { address ->
                            Spacer(Modifier.height(6.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Filled.LocationOn,
                                    contentDescription = null,
                                    tint = MarchColors.TextSecondary,
                                    modifier = Modifier.size(13.dp)
                                )
                                Spacer(Modifier.width(5.dp))
                                Text(
                                    text = address,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MarchColors.TextSecondary,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MetricChip(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        color = MarchColors.TextPrimary,
        modifier = Modifier
            .clip(RoundedCornerShape(9.dp))
            .background(MarchColors.Background.copy(alpha = 0.45f))
            .padding(horizontal = 10.dp, vertical = 6.dp)
    )
}
