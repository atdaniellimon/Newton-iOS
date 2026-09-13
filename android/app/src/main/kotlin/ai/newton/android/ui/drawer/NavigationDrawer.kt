package ai.newton.android.ui.drawer

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Laptop
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ai.newton.android.data.ConversationStore
import ai.newton.android.theme.NewtonColors
import ai.newton.shared.Conversation

@Composable
fun NewtonDrawerContent(
    store: ConversationStore,
    currentConversationId: String?,
    onSelectConversation: (String) -> Unit,
    onNewConversation: () -> Unit,
    onOpenRemoteStudio: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val conversations by store.conversations.collectAsState()

    ModalDrawerSheet(
        modifier = modifier
            .width(300.dp)
            .fillMaxHeight(),
        drawerContainerColor = NewtonColors.BgDark,
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight()
                .padding(16.dp),
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(vertical = 8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(NewtonColors.Sand),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "N",
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = NewtonColors.BgDark,
                        ),
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        text = "Newton",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = NewtonColors.TextPrimaryDark,
                    )
                    Text(
                        text = "Android Edition",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                        color = NewtonColors.TextSecondaryDark,
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Quick actions
            DrawerActionButton(
                icon = Icons.Default.Add,
                title = "Nueva Conversación",
                tint = NewtonColors.Sand,
                onClick = onNewConversation,
            )

            Spacer(modifier = Modifier.height(6.dp))

            DrawerActionButton(
                icon = Icons.Default.Laptop,
                title = "Mac Remote Studio",
                tint = NewtonColors.Aqua,
                onClick = onOpenRemoteStudio,
            )

            Spacer(modifier = Modifier.height(16.dp))
            HorizontalDivider(color = NewtonColors.BorderDark.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "CONVERSACIONES RECIENTES",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp,
                ),
                color = NewtonColors.TextMutedDark,
                modifier = Modifier.padding(horizontal = 4.dp),
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Conversations list
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                items(conversations, key = { it.id }) { item ->
                    val isSelected = item.id == currentConversationId
                    ConversationDrawerItem(
                        conversation = item,
                        isSelected = isSelected,
                        onClick = { onSelectConversation(item.id) },
                        onDelete = { store.remove(item.id) },
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(color = NewtonColors.BorderDark.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(8.dp))

            // Settings button
            DrawerActionButton(
                icon = Icons.Default.Settings,
                title = "Configuración",
                tint = NewtonColors.TextSecondaryDark,
                onClick = onOpenSettings,
            )
        }
    }
}

@Composable
private fun DrawerActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    tint: Color,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(NewtonColors.CardDark)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = title,
            tint = tint,
            modifier = Modifier.size(18.dp),
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = NewtonColors.TextPrimaryDark,
        )
    }
}

@Composable
private fun ConversationDrawerItem(
    conversation: Conversation,
    isSelected: Boolean,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isSelected) NewtonColors.Sand.copy(alpha = 0.12f) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.weight(1f),
        ) {
            Icon(
                imageVector = if (conversation.isPinned) Icons.Default.PushPin else Icons.Default.ChatBubbleOutline,
                contentDescription = null,
                tint = if (isSelected) NewtonColors.Sand else NewtonColors.TextMutedDark,
                modifier = Modifier.size(16.dp),
            )
            Spacer(modifier = Modifier.width(10.dp))
            Text(
                text = conversation.title,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                ),
                color = if (isSelected) NewtonColors.TextPrimaryDark else NewtonColors.TextSecondaryDark,
                maxLines = 1,
            )
        }

        IconButton(
            onClick = onDelete,
            modifier = Modifier.size(24.dp),
        ) {
            Icon(
                imageVector = Icons.Default.DeleteOutline,
                contentDescription = "Delete",
                tint = NewtonColors.TextMutedDark,
                modifier = Modifier.size(14.dp),
            )
        }
    }
}
