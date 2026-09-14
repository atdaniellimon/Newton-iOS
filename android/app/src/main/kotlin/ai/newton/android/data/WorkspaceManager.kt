package ai.newton.android.data

import ai.newton.shared.Workspace
import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class WorkspaceManager private constructor(private val appContext: Context) {

    companion object {
        private const val PREFS_NAME = "newton_workspaces_prefs"
        private const val KEY_ACTIVE_ID = "active_workspace_id"
        private const val KEY_WORKSPACES_JSON = "workspaces_json"

        @Volatile
        private var instance: WorkspaceManager? = null

        fun getInstance(context: Context): WorkspaceManager {
            return instance ?: synchronized(this) {
                instance ?: WorkspaceManager(context.applicationContext).also { instance = it }
            }
        }
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _activeWorkspaceId = MutableStateFlow(prefs.getString(KEY_ACTIVE_ID, "default") ?: "default")
    val activeWorkspaceId: StateFlow<String> = _activeWorkspaceId.asStateFlow()

    private val _workspaces = MutableStateFlow<List<Workspace>>(loadWorkspaces())
    val workspaces: StateFlow<List<Workspace>> = _workspaces.asStateFlow()

    val activeWorkspace: Workspace?
        get() {
            val id = _activeWorkspaceId.value
            if (id == "default") return null
            return _workspaces.value.firstOrNull { it.id == id }
        }

    fun setActiveWorkspace(id: String) {
        _activeWorkspaceId.value = id
        prefs.edit().putString(KEY_ACTIVE_ID, id).apply()
    }

    fun addWorkspace(
        name: String,
        icon: String = "folder.fill",
        color: String = "#F5A623",
        prompt: String = "",
    ): Workspace {
        val ws = Workspace(
            name = name,
            iconName = icon,
            colorHex = color,
            customSystemPrompt = prompt,
        )
        val updated = _workspaces.value + ws
        _workspaces.value = updated
        saveWorkspaces(updated)
        return ws
    }

    fun deleteWorkspace(id: String) {
        val updated = _workspaces.value.filterNot { it.id == id }
        _workspaces.value = updated
        if (_activeWorkspaceId.value == id) {
            setActiveWorkspace("default")
        }
        saveWorkspaces(updated)
    }

    fun updateWorkspace(workspace: Workspace) {
        val updated = _workspaces.value.map { if (it.id == workspace.id) workspace else it }
        _workspaces.value = updated
        saveWorkspaces(updated)
    }

    private fun loadWorkspaces(): List<Workspace> {
        val raw = prefs.getString(KEY_WORKSPACES_JSON, null) ?: return emptyList()
        return try {
            json.decodeFromString<List<Workspace>>(raw)
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun saveWorkspaces(list: List<Workspace>) {
        try {
            val raw = json.encodeToString(list)
            prefs.edit().putString(KEY_WORKSPACES_JSON, raw).apply()
        } catch (_: Exception) {}
    }
}
