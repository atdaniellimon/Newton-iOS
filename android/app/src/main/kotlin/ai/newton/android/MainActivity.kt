package ai.newton.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import ai.newton.android.chat.ChatViewModel
import ai.newton.android.data.ConversationStore
import ai.newton.android.data.SettingsRepository
import ai.newton.android.theme.NewtonTheme
import ai.newton.android.ui.chat.ChatScreen
import ai.newton.android.ui.drawer.NewtonDrawerContent
import ai.newton.android.ui.remote.DesktopRemoteControlScreen
import ai.newton.android.ui.remote.RemoteControlViewModel
import ai.newton.android.ui.settings.SettingsScreen
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val deepLinkHost = intent?.data?.host

        val store = ConversationStore(applicationContext)
        val settings = SettingsRepository(applicationContext)

        setContent {
            NewtonTheme(darkTheme = true) {
                NewtonApp(
                    store = store,
                    settings = settings,
                    deepLinkHost = deepLinkHost,
                )
            }
        }
    }
}

@Composable
fun NewtonApp(
    store: ConversationStore,
    settings: SettingsRepository,
    deepLinkHost: String? = null,
) {
    val navController = rememberNavController()
    val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)
    val scope = rememberCoroutineScope()

    val chatViewModel = remember { ChatViewModel(store, settings) }
    val remoteViewModel = remember { RemoteControlViewModel(settings) }

    val chatUiState by chatViewModel.ui.collectAsState()

    LaunchedEffect(deepLinkHost) {
        when (deepLinkHost) {
            "new" -> chatViewModel.newConversation()
            "remote" -> navController.navigate("remote")
            "settings" -> navController.navigate("settings")
        }
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            NewtonDrawerContent(
                store = store,
                currentConversationId = chatUiState.conversation?.id,
                onSelectConversation = { id ->
                    chatViewModel.open(id)
                    scope.launch { drawerState.close() }
                    navController.navigate("chat") {
                        popUpTo("chat") { inclusive = true }
                    }
                },
                onNewConversation = {
                    chatViewModel.newConversation()
                    scope.launch { drawerState.close() }
                    navController.navigate("chat") {
                        popUpTo("chat") { inclusive = true }
                    }
                },
                onOpenRemoteStudio = {
                    scope.launch { drawerState.close() }
                    navController.navigate("remote")
                },
                onOpenSettings = {
                    scope.launch { drawerState.close() }
                    navController.navigate("settings")
                },
            )
        },
    ) {
        NavHost(
            navController = navController,
            startDestination = "chat",
            modifier = Modifier.fillMaxSize(),
        ) {
            composable("chat") {
                ChatScreen(
                    viewModel = chatViewModel,
                    onOpenDrawer = { scope.launch { drawerState.open() } },
                )
            }

            composable("remote") {
                DesktopRemoteControlScreen(
                    viewModel = remoteViewModel,
                    onBack = { navController.popBackStack() },
                )
            }

            composable("settings") {
                SettingsScreen(
                    settings = settings,
                    onBack = { navController.popBackStack() },
                )
            }
        }
    }
}
