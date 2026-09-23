package ai.newton.android.ui.chat

import ai.newton.android.theme.NewtonColors
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class WebCitationItem(
    val title: String,
    val urlString: String,
    val snippet: String = "",
    val citationNumber: Int = 1,
)

/**
 * Android Jetpack Compose counterpart of Swift `WebCitationCardView`
 * (ios/Newton/Views/Components/WebCitationCardView.swift).
 */
@Composable
fun WebCitationCard(
    citation: WebCitationItem,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val host = remember(citation.urlString) {
        try {
            val uri = Uri.parse(citation.urlString)
            (uri.host ?: citation.urlString).replace("www.", "")
        } catch (_: Exception) {
            citation.urlString
        }
    }

    Column(
        modifier = modifier
            .width(220.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(NewtonColors.CardDark.copy(alpha = 0.7f))
            .border(0.8.dp, NewtonColors.Sand.copy(alpha = 0.25f), RoundedCornerShape(10.dp))
            .clickable {
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(citation.urlString))
                    context.startActivity(intent)
                } catch (_: Exception) {}
            }
            .padding(9.dp),
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(3.dp))
                    .background(NewtonColors.Sand.copy(alpha = 0.15f))
                    .padding(horizontal = 4.dp, vertical = 2.dp),
            ) {
                Text(
                    text = "[${citation.citationNumber}]",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 10.sp,
                    ),
                    color = NewtonColors.Sand,
                )
            }

            Icon(
                imageVector = Icons.Default.Public,
                contentDescription = null,
                tint = NewtonColors.Sand,
                modifier = Modifier.size(11.dp),
            )

            Text(
                text = host,
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 11.sp,
                ),
                color = NewtonColors.TextSecondaryDark,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )

            Icon(
                imageVector = Icons.Default.NorthEast,
                contentDescription = "Open",
                tint = NewtonColors.TextMutedDark,
                modifier = Modifier.size(10.dp),
            )
        }

        Text(
            text = citation.title,
            style = MaterialTheme.typography.bodySmall.copy(
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
            ),
            color = NewtonColors.TextPrimaryDark,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )

        if (citation.snippet.isNotBlank()) {
            Text(
                text = citation.snippet,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontSize = 10.5.sp,
                ),
                color = NewtonColors.TextSecondaryDark,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
