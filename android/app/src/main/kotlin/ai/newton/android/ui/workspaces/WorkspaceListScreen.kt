package ai.newton.android.ui.workspaces

import ai.newton.android.data.WorkspaceManager
import ai.newton.android.theme.NewtonColors
import ai.newton.android.ui.components.Hero3DCanvas
import ai.newton.shared.Workspace
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
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Android Jetpack Compose counterpart of Swift `WorkspaceListView`
 * (ios/Newton/Views/Workspaces/WorkspaceListView.swift).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkspaceListScreen(
    workspaceManager: WorkspaceManager,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val workspaces by workspaceManager.workspaces.collectAsState()
    val activeId by workspaceManager.activeWorkspaceId.collectAsState()
    var showCreateDialog by remember { mutableStateOf(false) }

    var newName by remember { mutableStateOf("") }
    var newPrompt by remember { mutableStateOf("") }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = NewtonColors.BgDark,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Espacios de Trabajo",
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Serif,
                        ),
                        color = NewtonColors.TextPrimaryDark,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = NewtonColors.Sand,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { showCreateDialog = true }) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "Create",
                            tint = NewtonColors.Sand,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = NewtonColors.BgDark,
                ),
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            Hero3DCanvas(isDark = true, modifier = Modifier.fillMaxSize())

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                // Default Global Workspace
                item {
                    val isGlobalActive = activeId == "default"
                    WorkspaceCard(
                        name = "Global",
                        description = "Instrucciones generales de Newton Singularity sin contexto de proyecto.",
                        isActive = isGlobalActive,
                        isDefault = true,
                        onClick = { workspaceManager.setActiveWorkspace("default") },
                        onDelete = {},
                    )
                }

                // Custom Workspaces
                items(workspaces, key = { it.id }) { ws ->
                    val isActive = activeId == ws.id
                    WorkspaceCard(
                        name = ws.name,
                        description = ws.customSystemPrompt.ifEmpty { "Sin prompt de sistema personalizado" },
                        isActive = isActive,
                        isDefault = false,
                        onClick = { workspaceManager.setActiveWorkspace(ws.id) },
                        onDelete = { workspaceManager.deleteWorkspace(ws.id) },
                    )
                }
            }

            // Create Workspace Dialog
            if (showCreateDialog) {
                AlertDialog(
                    onDismissRequest = { showCreateDialog = false },
                    title = {
                        Text(
                            text = "Nuevo Espacio de Trabajo",
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.Bold,
                                color = NewtonColors.Sand,
                            ),
                        )
                    },
                    text = {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(
                                text = "Configura un contexto y prompt de sistema persistente para este proyecto.",
                                style = MaterialTheme.typography.bodySmall,
                                color = NewtonColors.TextSecondaryDark,
                            )
                            TextField(
                                value = newName,
                                onValueChange = { newName = it },
                                placeholder = { Text("Nombre (e.g. Proyecto Quantum)") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                                colors = TextFieldDefaults.colors(
                                    focusedContainerColor = NewtonColors.CardDark,
                                    unfocusedContainerColor = NewtonColors.CardDark,
                                    focusedTextColor = NewtonColors.TextPrimaryDark,
                                    unfocusedTextColor = NewtonColors.TextPrimaryDark,
                                ),
                            )
                            TextField(
                                value = newPrompt,
                                onValueChange = { newPrompt = it },
                                placeholder = { Text("Prompt de sistema personalizado (reglas, arquitectura, stack)...") },
                                modifier = Modifier.fillMaxWidth(),
                                minLines = 3,
                                maxLines = 5,
                                colors = TextFieldDefaults.colors(
                                    focusedContainerColor = NewtonColors.CardDark,
                                    unfocusedContainerColor = NewtonColors.CardDark,
                                    focusedTextColor = NewtonColors.TextPrimaryDark,
                                    unfocusedTextColor = NewtonColors.TextPrimaryDark,
                                ),
                            )
                        }
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                if (newName.isNotBlank()) {
                                    val created = workspaceManager.addWorkspace(
                                        name = newName.trim(),
                                        prompt = newPrompt.trim(),
                                    )
                                    workspaceManager.setActiveWorkspace(created.id)
                                    newName = ""
                                    newPrompt = ""
                                    showCreateDialog = false
                                }
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = NewtonColors.Sand,
                                contentColor = Color.Black,
                            ),
                        ) {
                            Text("Guardar", fontWeight = FontWeight.Bold)
                        }
                    },
                    dismissButton = {
                        OutlinedButton(onClick = { showCreateDialog = false }) {
                            Text("Cancelar", color = NewtonColors.TextSecondaryDark)
                        }
                    },
                    containerColor = NewtonColors.SurfaceDark,
                )
            }
        }
    }
}

@Composable
private fun WorkspaceCard(
    name: String,
    description: String,
    isActive: Boolean,
    isDefault: Boolean,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isActive) NewtonColors.Sand.copy(alpha = 0.14f) else NewtonColors.CardDark)
            .border(
                1.dp,
                if (isActive) NewtonColors.Sand.copy(alpha = 0.6f) else NewtonColors.BorderDark,
                RoundedCornerShape(14.dp),
            )
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(42.dp)
                .clip(CircleShape)
                .background(if (isActive) NewtonColors.Sand else NewtonColors.SurfaceDark),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = if (isDefault) Icons.Default.Public else Icons.Default.Folder,
                contentDescription = null,
                tint = if (isActive) Color.Black else NewtonColors.Sand,
                modifier = Modifier.size(22.dp),
            )
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.bodyLarge.copy(
                        fontWeight = if (isActive) FontWeight.Bold else FontWeight.SemiBold,
                    ),
                    color = NewtonColors.TextPrimaryDark,
                )
                if (isActive) {
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "ACTIVO",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                        color = NewtonColors.Sand,
                    )
                }
            }
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = NewtonColors.TextSecondaryDark,
                maxLines = 2,
            )
        }

        if (isActive) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "Active",
                tint = NewtonColors.Sand,
                modifier = Modifier.size(20.dp),
            )
        } else if (!isDefault) {
            IconButton(onClick = onDelete) {
                Icon(
                    imageVector = Icons.Default.DeleteOutline,
                    contentDescription = "Delete",
                    tint = NewtonColors.TextMutedDark,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}
