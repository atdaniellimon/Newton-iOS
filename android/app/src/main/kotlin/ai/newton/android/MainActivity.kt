package ai.newton.android

import ai.newton.android.chat.ChatViewModel
import ai.newton.android.data.AuthManager
import ai.newton.android.data.CloudChatService
import ai.newton.android.data.ConversationStore
import ai.newton.android.data.SettingsRepository
import ai.newton.android.data.WorkspaceManager
import ai.newton.android.theme.NewtonTheme
import ai.newton.android.ui.auth.AuthScreen
import ai.newton.android.ui.chat.ChatScreen
import ai.newton.android.ui.chat.VoiceCallScreen
import ai.newton.android.ui.gallery.ArtGalleryScreen
import ai.newton.android.ui.remote.DesktopRemoteControlScreen
import ai.newton.android.ui.remote.RemoteControlViewModel
import ai.newton.android.ui.settings.SettingsScreen
import ai.newton.android.ui.sidebar.ConversationListScreen
import ai.newton.android.ui.workspaces.WorkspaceListScreen
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val deepLinkHost = intent?.data?.host

        val auth = AuthManager.getInstance(applicationContext)
        val cloudService = CloudChatService.getInstance(auth)
        val store = ConversationStore(applicationContext)
        val settings = SettingsRepository(applicationContext)
        val workspaceManager = WorkspaceManager.getInstance(applicationContext)

        setContent {
            NewtonTheme(darkTheme = true) {
                NewtonApp(
                    auth = auth,
                    cloudService = cloudService,
                    store = store,
                    settings = settings,
                    workspaceManager = workspaceManager,
                    deepLinkHost = deepLinkHost,
                )
            }
        }
    }
}

@Composable
fun NewtonApp(
    auth: AuthManager,
    cloudService: CloudChatService,
    store: ConversationStore,
    settings: SettingsRepository,
    workspaceManager: WorkspaceManager,
    deepLinkHost: String? = null,
) {
    val isLoggedIn by auth.isLoggedIn.collectAsState()
    val scope = rememberCoroutineScope()

    if (!isLoggedIn) {
        AuthScreen(
            authManager = auth,
            onAuthSuccess = {
                scope.launch {
                    auth.refreshUserInfo()
                    store.syncWithRemoteServer(cloudService, auth)
                }
            },
        )
    } else {
        val navController = rememberNavController()

        val chatViewModel: ChatViewModel = viewModel(
            factory = object : ViewModelProvider.Factory {
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    @Suppress("UNCHECKED_CAST")
                    return ChatViewModel(
                        store = store,
                        settings = settings,
                        auth = auth,
                        cloudService = cloudService,
                        workspaceManager = workspaceManager,
                    ) as T
                }
            }
        )

        val remoteViewModel: RemoteControlViewModel = viewModel(
            factory = object : ViewModelProvider.Factory {
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    @Suppress("UNCHECKED_CAST")
                    return RemoteControlViewModel(settings) as T
                }
            }
        )

        // Setup global sync listener
        LaunchedEffect(isLoggedIn) {
            cloudService.startGlobalSyncListener(scope) { event ->
                store.handleRemoteSyncEvent(event)
            }
        }

        // Deep links handling
        LaunchedEffect(deepLinkHost) {
            when (deepLinkHost) {
                "new" -> {
                    val id = chatViewModel.newConversation()
                    navController.navigate("chat/$id")
                }
                "ghost" -> {
                    val ghost = store.createGhostConversation("Sesión Fantasma")
                    chatViewModel.open(ghost.id)
                    navController.navigate("chat/${ghost.id}")
                }
                "voice" -> navController.navigate("voice")
                "remote" -> navController.navigate("remote")
                "settings" -> navController.navigate("settings")
            }
        }

        NavHost(
            navController = navController,
            startDestination = "conversations",
            modifier = Modifier.fillMaxSize(),
        ) {
            composable("conversations") {
                ConversationListScreen(
                    store = store,
                    auth = auth,
                    cloudService = cloudService,
                    onSelectConversation = { id ->
                        chatViewModel.open(id)
                        navController.navigate("chat/$id")
                    },
                    onOpenRemoteStudio = { navController.navigate("remote") },
                    onOpenArtGallery = { navController.navigate("gallery") },
                    onOpenSettings = { navController.navigate("settings") },
                )
            }

            composable(
                route = "chat/{convoId}",
                arguments = listOf(navArgument("convoId") { type = NavType.StringType }),
            ) { backStackEntry ->
                val convoId = backStackEntry.arguments?.getString("convoId").orEmpty()
                LaunchedEffect(convoId) {
                    chatViewModel.open(convoId)
                }
                ChatScreen(
                    viewModel = chatViewModel,
                    workspaceManager = workspaceManager,
                    onBack = { navController.popBackStack() },
                    onOpenRemoteStudio = { navController.navigate("remote") },
                    onOpenVoiceCall = { navController.navigate("voice") },
                )
            }

            composable("remote") {
                DesktopRemoteControlScreen(
                    viewModel = remoteViewModel,
                    onBack = { navController.popBackStack() },
                )
            }

            composable("workspaces") {
                WorkspaceListScreen(
                    workspaceManager = workspaceManager,
                    onBack = { navController.popBackStack() },
                )
            }

            composable("gallery") {
                ArtGalleryScreen(
                    store = store,
                    onBack = { navController.popBackStack() },
                )
            }

            composable("voice") {
                val chatUi by chatViewModel.ui.collectAsState()
                VoiceCallScreen(
                    conversationTitle = chatUi.conversation?.title ?: "Newton",
                    onDismiss = { navController.popBackStack() },
                )
            }

            composable("settings") {
                SettingsScreen(
                    authManager = auth,
                    settings = settings,
                    onBack = { navController.popBackStack() },
                    onLogout = {
                        navController.popBackStack("conversations", inclusive = true)
                    },
                )
            }
        }
    }
}
