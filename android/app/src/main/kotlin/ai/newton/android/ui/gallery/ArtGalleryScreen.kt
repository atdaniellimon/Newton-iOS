package ai.newton.android.ui.gallery

import ai.newton.android.data.ConversationStore
import ai.newton.android.theme.NewtonColors
import ai.newton.android.ui.components.Hero3DCanvas
import ai.newton.shared.MessageRole
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage

data class GalleryItem(
    val imageUrl: String,
    val conversationTitle: String,
    val date: Long,
    val isGenerated: Boolean,
)

/**
 * Android Jetpack Compose counterpart of Swift `ArtGalleryView`
 * (ios/Newton/Views/Components/ArtGalleryView.swift).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ArtGalleryScreen(
    store: ConversationStore,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val conversations by store.conversations.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) } // 0: Generadas, 1: Enviadas
    var previewUrl by remember { mutableStateOf<String?>(null) }

    val generatedImages = remember(conversations) {
        val list = mutableListOf<GalleryItem>()
        for (c in conversations) {
            for (m in c.messages) {
                if (m.role == MessageRole.ASSISTANT && !m.imageUrl.isNullOrEmpty()) {
                    list.add(
                        GalleryItem(
                            imageUrl = m.imageUrl!!,
                            conversationTitle = c.title,
                            date = c.updatedAt,
                            isGenerated = true,
                        )
                    )
                }
            }
        }
        list.reversed()
    }

    val sentImages = remember(conversations) {
        val list = mutableListOf<GalleryItem>()
        for (c in conversations) {
            for (m in c.messages) {
                if (m.role == MessageRole.USER && !m.imageUrl.isNullOrEmpty()) {
                    list.add(
                        GalleryItem(
                            imageUrl = m.imageUrl!!,
                            conversationTitle = c.title,
                            date = c.updatedAt,
                            isGenerated = false,
                        )
                    )
                }
            }
        }
        list.reversed()
    }

    val activeList = if (selectedTab == 0) generatedImages else sentImages

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = NewtonColors.BgDark,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Galería de Arte",
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

            Column(modifier = Modifier.fillMaxSize()) {
                // Tab row filter
                TabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = NewtonColors.CardDark,
                    contentColor = NewtonColors.Sand,
                    indicator = { tabPositions ->
                        TabRowDefaults.SecondaryIndicator(
                            Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                            color = NewtonColors.Sand,
                        )
                    },
                    modifier = Modifier
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                        .clip(RoundedCornerShape(12.dp)),
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = {
                            Text(
                                text = "Generadas (${generatedImages.size})",
                                fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal,
                            )
                        },
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = {
                            Text(
                                text = "Enviadas (${sentImages.size})",
                                fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal,
                            )
                        },
                    )
                }

                if (activeList.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .weight(1f),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Icon(
                                imageVector = if (selectedTab == 0) Icons.Default.Collections else Icons.Default.Image,
                                contentDescription = null,
                                tint = NewtonColors.Sand.copy(alpha = 0.5f),
                                modifier = Modifier.size(54.dp),
                            )
                            Text(
                                text = if (selectedTab == 0) "No hay imágenes generadas aún" else "No hay imágenes enviadas aún",
                                style = MaterialTheme.typography.titleSmall.copy(fontFamily = FontFamily.Serif),
                                color = NewtonColors.TextSecondaryDark,
                            )
                            Text(
                                text = "Pídele a Newton 'Crea una imagen de...' para verlas aquí.",
                                style = MaterialTheme.typography.bodySmall,
                                color = NewtonColors.TextMutedDark,
                            )
                        }
                    }
                } else {
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        contentPadding = PaddingValues(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        items(activeList) { item ->
                            Box(
                                modifier = Modifier
                                    .aspectRatio(1f)
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(NewtonColors.CardDark)
                                    .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(14.dp))
                                    .clickable { previewUrl = item.imageUrl },
                            ) {
                                AsyncImage(
                                    model = item.imageUrl,
                                    contentDescription = item.conversationTitle,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize(),
                                )

                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .align(Alignment.BottomCenter)
                                        .background(Color.Black.copy(alpha = 0.65f))
                                        .padding(horizontal = 8.dp, vertical = 4.dp),
                                ) {
                                    Text(
                                        text = item.conversationTitle,
                                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                        color = Color.White,
                                        maxLines = 1,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Fullscreen Preview Overlay
            previewUrl?.let { url ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.95f))
                        .clickable { previewUrl = null },
                    contentAlignment = Alignment.Center,
                ) {
                    AsyncImage(
                        model = url,
                        contentDescription = "Preview",
                        contentScale = ContentScale.Fit,
                        modifier = Modifier
                            .fillMaxSize(0.9f)
                            .clip(RoundedCornerShape(16.dp)),
                    )

                    IconButton(
                        onClick = { previewUrl = null },
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(24.dp)
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.2f)),
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
                            tint = Color.White,
                        )
                    }
                }
            }
        }
    }
}
