package ai.newton.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import ai.newton.android.theme.NewtonTheme

/**
 * Entry point. Deep links mirror iOS (`newton://new`, `newton://ghost`,
 * `newton://voice`); full NavGraph + chat UI arrive in the chat milestone.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val deepLinkHost = intent?.data?.host
        setContent {
            NewtonTheme(darkTheme = true) {
                NewtonScaffoldScreen(deepLinkHost = deepLinkHost)
            }
        }
    }
}

@Composable
fun NewtonScaffoldScreen(deepLinkHost: String? = null) {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Newton",
                style = MaterialTheme.typography.displayMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Android scaffold listo — el chat llega en el siguiente milestone.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (deepLinkHost != null) {
                Spacer(Modifier.height(12.dp))
                Text(
                    text = "Deep link: newton://$deepLinkHost",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            Spacer(Modifier.height(24.dp))
            Text(
                text = "Ya cableado: modelos, SSE, OrbitEngine, tema Everforest & Sand.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun NewtonScaffoldPreview() {
    NewtonTheme(darkTheme = true) {
        NewtonScaffoldScreen(deepLinkHost = "new")
    }
}
