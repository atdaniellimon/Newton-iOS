package ai.newton.android.ui.components

import ai.newton.android.theme.NewtonColors
import ai.newton.shared.FileAttachment
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.DataObject
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.FolderZip
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.InsertDriveFile
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Android Jetpack Compose counterpart of Swift `AttachmentCardView`
 * (ios/Newton/Views/Components/AttachmentCardView.swift).
 */
@Composable
fun AttachmentCard(
    attachment: FileAttachment,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
) {
    var showPreviewModal by remember { mutableStateOf(false) }

    val icon: ImageVector = when (attachment.iconKey) {
        "code" -> Icons.Default.Code
        "pdf" -> Icons.Default.PictureAsPdf
        "data" -> Icons.Default.DataObject
        "image" -> Icons.Default.Image
        "audio" -> Icons.Default.GraphicEq
        "archive" -> Icons.Default.FolderZip
        "doc" -> Icons.Default.Description
        else -> Icons.Default.InsertDriveFile
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(NewtonColors.CardDark)
            .border(0.8.dp, NewtonColors.BorderDark.copy(alpha = 0.6f), RoundedCornerShape(12.dp))
            .clickable {
                if (onClick != null) {
                    onClick()
                } else {
                    showPreviewModal = true
                }
            }
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Icon container box
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(NewtonColors.Sand.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = attachment.fileName,
                tint = NewtonColors.Sand,
                modifier = Modifier.size(20.dp),
            )
        }

        // Details
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = attachment.fileName,
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                color = NewtonColors.TextPrimaryDark,
                maxLines = 1,
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.padding(top = 2.dp),
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(NewtonColors.Sand.copy(alpha = 0.12f))
                        .padding(horizontal = 4.dp, vertical = 1.dp),
                ) {
                    Text(
                        text = attachment.fileExtension.uppercase(),
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                        color = NewtonColors.Sand,
                    )
                }

                Text(
                    text = attachment.fileSizeFormatted,
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                    ),
                    color = NewtonColors.TextSecondaryDark,
                )

                if (attachment.lineCount != null) {
                    Text(
                        text = "• ${attachment.lineCount} líneas",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                        color = NewtonColors.TextMutedDark,
                    )
                }
            }
        }

        Icon(
            imageVector = Icons.Default.OpenInNew,
            contentDescription = null,
            tint = NewtonColors.TextMutedDark,
            modifier = Modifier.size(16.dp),
        )
    }

    if (showPreviewModal) {
        AlertDialog(
            onDismissRequest = { showPreviewModal = false },
            containerColor = NewtonColors.SurfaceDark,
            title = {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(imageVector = icon, contentDescription = null, tint = NewtonColors.Sand, modifier = Modifier.size(20.dp))
                    Text(
                        text = attachment.fileName,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = NewtonColors.TextPrimaryDark,
                        maxLines = 1,
                    )
                }
            },
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(
                            text = "Tamaño: ${attachment.fileSizeFormatted}",
                            style = MaterialTheme.typography.bodySmall,
                            color = NewtonColors.TextSecondaryDark,
                        )
                        Text(
                            text = "Tipo: ${attachment.mimeType}",
                            style = MaterialTheme.typography.bodySmall,
                            color = NewtonColors.TextMutedDark,
                        )
                    }

                    if (!attachment.previewSnippet.isNullOrEmpty()) {
                        Text(
                            text = "Vista previa de contenido:",
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = NewtonColors.Sand,
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.Black.copy(alpha = 0.5f))
                                .padding(10.dp),
                        ) {
                            Text(
                                text = attachment.previewSnippet.orEmpty(),
                                style = MaterialTheme.typography.bodySmall.copy(
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 11.sp,
                                ),
                                color = NewtonColors.TextPrimaryDark,
                            )
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = { showPreviewModal = false },
                    colors = ButtonDefaults.buttonColors(containerColor = NewtonColors.Sand, contentColor = Color.Black),
                ) {
                    Text("Cerrar", fontWeight = FontWeight.Bold)
                }
            },
        )
    }
}
