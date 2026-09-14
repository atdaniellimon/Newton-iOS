package ai.newton.android.ui.sidebar

import ai.newton.android.data.AuthManager
import ai.newton.android.data.CloudChatService
import ai.newton.android.data.ConversationStore
import ai.newton.android.theme.NewtonColors
import ai.newton.android.ui.components.Hero3DCanvas
import ai.newton.shared.Conversation
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Laptop
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

/**
 * Android Jetpack Compose counterpart of Swift `ConversationListView`
 * (ios/Newton/Views/Sidebar/ConversationListView.swift).
 *
 * Native Newton Studio layout with Quick Studio Navigation, Chat Pinning,
 * Cloud Sync, bottom Settings gear and "+ New chat" pill.
 */
@Composable
fun ConversationListScreen(
    store: ConversationStore,
    auth: AuthManager,
    cloudService: CloudChatService,
    onSelectConversation: (String) -> Unit,
    onOpenRemoteStudio: () -> Unit,
    onOpenWorkspaces: () -> Unit,
    onOpenArtGallery: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val conversations by store.conversations.collectAsState()

    LaunchedEffect(auth.isLoggedIn) {
        if (auth.isLoggedIn.value) {
            store.syncWithRemoteServer(cloudService, auth)
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(NewtonColors.BgDark),
    ) {
        // 3D kinetic wave canvas background
        Hero3DCanvas(
            isDark = true,
            modifier = Modifier.fillMaxSize(),
        )

        Column(
            modifier = Modifier.fillMaxSize(),
        ) {
            // Top Brand Title
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Newton",
                    style = MaterialTheme.typography.headlineLarge.copy(
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                    ),
                    color = NewtonColors.TextPrimaryDark,
                )
            }

            // Studio Section Navigation Items
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SidebarItemRow(
                    icon = Icons.Default.ChatBubbleOutline,
                    title = "Chats",
                    isSelected = true,
                    onClick = {},
                )

                SidebarItemRow(
                    icon = Icons.Default.AutoAwesome,
                    title = "Sesión Fantasma",
                    tint = NewtonColors.GhostPurple,
                    isSelected = false,
                    onClick = {
                        val ghost = store.createGhostConversation("Sesión Fantasma")
                        onSelectConversation(ghost.id)
                    },
                )

                SidebarItemRow(
                    icon = Icons.Default.Laptop,
                    title = "Control Remoto Mac",
                    tint = NewtonColors.Aqua,
                    isSelected = false,
                    onClick = onOpenRemoteStudio,
                )

                SidebarItemRow(
                    icon = Icons.Default.Folder,
                    title = "Espacios de trabajo",
                    isSelected = false,
                    onClick = onOpenWorkspaces,
                )

                SidebarItemRow(
                    icon = Icons.Default.Collections,
                    title = "Galería de arte",
                    isSelected = false,
                    onClick = onOpenArtGallery,
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

            // "Recents" Section Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 6.dp),
            ) {
                Text(
                    text = "RECIENTES",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp,
                    ),
                    color = NewtonColors.TextMutedDark,
                )
            }

            // Conversations List with Pinning and Deletion
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                items(conversations, key = { it.id }) { convo ->
                    ConversationRow(
                        conversation = convo,
                        onClick = { onSelectConversation(convo.id) },
                        onTogglePin = { store.togglePin(convo.id) },
                        onDelete = {
                            store.remove(convo.id)
                            scope.launch {
                                try {
                                    cloudService.deleteChat(convo.id)
                                } catch (_: Exception) {}
                            }
                        },
                    )
                }
            }

            HorizontalDivider(
                color = NewtonColors.BorderDark.copy(alpha = 0.5f),
                thickness = 0.8.dp,
            )

            // Bottom Bar: Settings Gear on left + "+ New chat" pill on right
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(NewtonColors.BgDark)
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                // Settings Gear Button
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(NewtonColors.SurfaceDark)
                        .clickable(onClick = onOpenSettings),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Settings",
                        tint = NewtonColors.TextSecondaryDark,
                        modifier = Modifier.size(20.dp),
                    )
                }

                // "+ New chat" pill button
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(24.dp))
                        .background(Color.Black.copy(alpha = 0.85f))
                        .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(24.dp))
                        .clickable {
                            val newConvo = store.createConversation("Nueva Conversación")
                            scope.launch {
                                try {
                                    val remote = cloudService.createChat(title = newConvo.title)
                                    store.updateConversationId(newConvo.id, remote.id, remote)
                                    onSelectConversation(remote.id)
                                } catch (_: Exception) {
                                    onSelectConversation(newConvo.id)
                                }
                            }
                        }
                        .padding(horizontal = 20.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(
                        text = "Nuevo chat",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontWeight = FontWeight.SemiBold,
                        ),
                        color = Color.White,
                    )
                }
            }
        }
    }
}

@Composable
private fun SidebarItemRow(
    icon: ImageVector,
    title: String,
    isSelected: Boolean,
    tint: Color = NewtonColors.Sand,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isSelected) NewtonColors.CardDark.copy(alpha = 0.75f) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = title,
            tint = if (isSelected) tint else NewtonColors.TextSecondaryDark,
            modifier = Modifier.size(20.dp),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium.copy(
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            ),
            color = if (isSelected) NewtonColors.TextPrimaryDark else NewtonColors.TextSecondaryDark,
        )
    }
}

@Composable
private fun ConversationRow(
    conversation: Conversation,
    onClick: () -> Unit,
    onTogglePin: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (conversation.isPinned) {
                Icon(
                    imageVector = Icons.Default.PushPin,
                    contentDescription = "Pinned",
                    tint = NewtonColors.Sand,
                    modifier = Modifier.size(13.dp),
                )
            }
            if (conversation.isGhost) {
                Icon(
                    imageVector = Icons.Default.AutoAwesome,
                    contentDescription = "Ghost",
                    tint = NewtonColors.GhostPurple,
                    modifier = Modifier.size(13.dp),
                )
            }
            Text(
                text = conversation.title,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontWeight = if (conversation.isPinned) FontWeight.SemiBold else FontWeight.Normal,
                ),
                color = NewtonColors.TextPrimaryDark,
                maxLines = 1,
            )
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(
                onClick = onTogglePin,
                modifier = Modifier.size(28.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.PushPin,
                    contentDescription = if (conversation.isPinned) "Unpin" else "Pin",
                    tint = if (conversation.isPinned) NewtonColors.Sand else NewtonColors.TextMutedDark,
                    modifier = Modifier.size(14.dp),
                )
            }
            IconButton(
                onClick = onDelete,
                modifier = Modifier.size(28.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.DeleteOutline,
                    contentDescription = "Delete",
                    tint = NewtonColors.TextMutedDark,
                    modifier = Modifier.size(15.dp),
                )
            }
        }
    }
}
