package ai.newton.android.ui.sidebar

import ai.newton.android.data.AuthManager
import ai.newton.android.data.CloudChatService
import ai.newton.android.data.ConversationStore
import ai.newton.android.theme.NewtonColors
import ai.newton.android.ui.components.Hero3DCanvas
import ai.newton.shared.Conversation
import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.ExperimentalFoundationApi
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
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Laptop
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

/**
 * Android Jetpack Compose counterpart of Swift `ConversationListView`.
 * Clean, modern editorial chat list without cluttering host pills or horizontal filters.
 * Structured by clean semantic sections: Studio Shortcuts, Pinned (if any), and Recents.
 */
@Composable
fun ConversationListScreen(
    store: ConversationStore,
    auth: AuthManager,
    cloudService: CloudChatService,
    onSelectConversation: (String) -> Unit,
    onOpenRemoteStudio: () -> Unit,
    onOpenArtGallery: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val conversations by store.conversations.collectAsState()

    LaunchedEffect(auth.isLoggedIn) {
        if (auth.isLoggedIn.value) {
            store.syncWithRemoteServer(cloudService, auth)
            cloudService.startGlobalSyncListener { event ->
                store.handleRemoteSyncEvent(event)
            }
        }
    }

    val pinnedList = remember(conversations) { conversations.filter { it.isPinned } }
    val recentsList = remember(conversations) { conversations.filter { !it.isPinned } }

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
            // Clean Brand Title Header (Editorial Serif)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 20.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = "Newton",
                    style = MaterialTheme.typography.headlineLarge.copy(
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = (-0.5).sp,
                    ),
                    color = NewtonColors.TextPrimaryDark,
                )
            }

            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                // Section 1: Studio Shortcuts
                item(key = "studio_shortcuts") {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        SidebarItemRow(
                            icon = Icons.Default.AutoAwesome,
                            title = "Sesión Fantasma",
                            subtitle = "Efímera, sin rastro en la nube",
                            tint = NewtonColors.GhostPurple,
                            onClick = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                val ghost = store.createGhostConversation("Sesión Fantasma")
                                onSelectConversation(ghost.id)
                            },
                        )

                        SidebarItemRow(
                            icon = Icons.Default.Laptop,
                            title = "Remote Studio (Mac)",
                            subtitle = "Consola, workspaces y herramientas",
                            tint = NewtonColors.Aqua,
                            onClick = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                onOpenRemoteStudio()
                            },
                        )

                        SidebarItemRow(
                            icon = Icons.Default.Collections,
                            title = "Galería de arte",
                            subtitle = "Creaciones visuales generadas",
                            tint = NewtonColors.Sand,
                            onClick = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                onOpenArtGallery()
                            },
                        )
                    }
                }

                // Section 2: Pinned (if any)
                if (pinnedList.isNotEmpty()) {
                    item(key = "header_pinned") {
                        SectionHeader(title = "FIJADOS")
                    }

                    items(pinnedList, key = { "pinned_${it.id}" }) { convo ->
                        ConversationRowItem(
                            conversation = convo,
                            onClick = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                onSelectConversation(convo.id)
                            },
                            onTogglePin = {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                store.togglePin(convo.id)
                            },
                            onDelete = {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                store.remove(convo.id)
                                scope.launch {
                                    try { cloudService.deleteChat(convo.id) } catch (_: Exception) {}
                                }
                            },
                        )
                    }

                    item(key = "spacer_pinned") {
                        Spacer(modifier = Modifier.height(10.dp))
                    }
                }

                // Section 3: Recents
                item(key = "header_recents") {
                    SectionHeader(title = if (pinnedList.isNotEmpty()) "RECIENTES" else "CONVERSACIONES")
                }

                if (recentsList.isEmpty() && pinnedList.isEmpty()) {
                    item(key = "empty_state") {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 40.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "Sin conversaciones aún.\nToca '+ Nuevo chat' para comenzar.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = NewtonColors.TextMutedDark,
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                            )
                        }
                    }
                } else {
                    items(recentsList, key = { convo -> convo.id }) { convo ->
                        ConversationRowItem(
                            conversation = convo,
                            onClick = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                onSelectConversation(convo.id)
                            },
                            onTogglePin = {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                store.togglePin(convo.id)
                            },
                            onDelete = {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                store.remove(convo.id)
                                scope.launch {
                                    try { cloudService.deleteChat(convo.id) } catch (_: Exception) {}
                                }
                            },
                        )
                    }
                }

                item(key = "bottom_spacer") {
                    Spacer(modifier = Modifier.height(16.dp))
                }
            }

            HorizontalDivider(
                color = NewtonColors.BorderDark.copy(alpha = 0.5f),
                thickness = 0.8.dp,
            )

            // Bottom Bar: Settings Gear + "+ Nuevo chat" pill
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(NewtonColors.BgDark.copy(alpha = 0.95f))
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
                        .clickable {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onOpenSettings()
                        },
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
                        .background(Color.Black.copy(alpha = 0.88f))
                        .border(1.dp, NewtonColors.Sand.copy(alpha = 0.4f), RoundedCornerShape(24.dp))
                        .clickable {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
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
                        tint = NewtonColors.Sand,
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
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelSmall.copy(
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
        ),
        color = NewtonColors.TextMutedDark,
        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

@Composable
private fun SidebarItemRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    tint: Color = NewtonColors.Sand,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(NewtonColors.CardDark.copy(alpha = 0.6f))
            .border(0.8.dp, NewtonColors.BorderDark.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(tint.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = tint,
                modifier = Modifier.size(18.dp),
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontWeight = FontWeight.SemiBold,
                ),
                color = NewtonColors.TextPrimaryDark,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontSize = 11.sp,
                ),
                color = NewtonColors.TextSecondaryDark,
                maxLines = 1,
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ConversationRowItem(
    conversation: Conversation,
    onClick: () -> Unit,
    onTogglePin: () -> Unit,
    onDelete: () -> Unit,
) {
    var showContextMenu by remember { mutableStateOf(false) }

    val lastMessageText = remember(conversation.messages) {
        val last = conversation.messages.lastOrNull()
        when {
            last == null -> "Sin mensajes"
            last.content.isNotBlank() -> last.content.trim().replace("\n", " ")
            last.thinkingContent != null -> "Pensamiento formulado..."
            last.orbitResults.isNotEmpty() -> "Ejecución Orbit: ${last.orbitResults.first().orbitName}"
            else -> "Adjunto"
        }
    }

    val relativeTime = remember(conversation.updatedAt) {
        DateUtils.getRelativeTimeSpanString(
            conversation.updatedAt,
            System.currentTimeMillis(),
            DateUtils.MINUTE_IN_MILLIS,
            DateUtils.FORMAT_ABBREV_RELATIVE
        ).toString()
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (conversation.isPinned) NewtonColors.CardDark else Color.Transparent)
            .combinedClickable(
                onClick = onClick,
                onLongClick = { showContextMenu = true },
            )
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                // Row 1: Badges & Title
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (conversation.isPinned) {
                        Icon(
                            imageVector = Icons.Default.PushPin,
                            contentDescription = "Pinned",
                            tint = NewtonColors.Sand,
                            modifier = Modifier.size(12.dp),
                        )
                    }
                    if (conversation.isGhost) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = "Ghost",
                            tint = NewtonColors.GhostPurple,
                            modifier = Modifier.size(12.dp),
                        )
                    }
                    if (conversation.isRemoteCodeChat) {
                        Icon(
                            imageVector = Icons.Default.Terminal,
                            contentDescription = "Remote Task",
                            tint = NewtonColors.Aqua,
                            modifier = Modifier.size(12.dp),
                        )
                    }

                    Text(
                        text = conversation.title,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontWeight = if (conversation.isPinned) FontWeight.SemiBold else FontWeight.Medium,
                        ),
                        color = NewtonColors.TextPrimaryDark,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )

                    if (conversation.isRemoteCodeChat && !conversation.workspaceName.isNullOrEmpty()) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(4.dp))
                                .background(NewtonColors.Aqua.copy(alpha = 0.15f))
                                .padding(horizontal = 4.dp, vertical = 1.dp),
                        ) {
                            Text(
                                text = conversation.workspaceName.orEmpty(),
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontSize = 9.sp,
                                    fontFamily = FontFamily.Monospace,
                                ),
                                color = NewtonColors.Aqua,
                            )
                        }
                    }
                }

                // Row 2: Snippet of last message
                Text(
                    text = lastMessageText,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontSize = 12.sp,
                    ),
                    color = NewtonColors.TextSecondaryDark,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            Spacer(modifier = Modifier.width(10.dp))

            // Relative timestamp
            Text(
                text = relativeTime,
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = 11.sp,
                ),
                color = NewtonColors.TextMutedDark,
            )
        }

        // Context Menu (Long-press)
        DropdownMenu(
            expanded = showContextMenu,
            onDismissRequest = { showContextMenu = false },
            modifier = Modifier.background(NewtonColors.SurfaceDark),
        ) {
            DropdownMenuItem(
                text = {
                    Text(
                        text = if (conversation.isPinned) "Desfijar" else "Fijar arriba",
                        color = NewtonColors.TextPrimaryDark,
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.PushPin,
                        contentDescription = null,
                        tint = NewtonColors.Sand,
                    )
                },
                onClick = {
                    showContextMenu = false
                    onTogglePin()
                },
            )

            DropdownMenuItem(
                text = {
                    Text(
                        text = "Eliminar conversación",
                        color = NewtonColors.CoralRed,
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.DeleteOutline,
                        contentDescription = null,
                        tint = NewtonColors.CoralRed,
                    )
                },
                onClick = {
                    showContextMenu = false
                    onDelete()
                },
            )
        }
    }
}
