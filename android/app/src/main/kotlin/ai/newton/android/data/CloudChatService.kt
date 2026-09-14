package ai.newton.android.data

import ai.newton.shared.AIProvider
import ai.newton.shared.Conversation
import ai.newton.shared.Message
import ai.newton.shared.MessageRole
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

@Serializable
data class CloudChatDTO(
    val id: String,
    val title: String,
    val model: String? = null,
    val system_prompt: String? = null,
    val is_pinned: Int? = null,
    val created_at: Double? = null,
    val updated_at: Double? = null,
    val last_message: String? = null,
    val message_count: Int? = null,
)

enum class CloudSyncEventType {
    CHAT_CREATED,
    CHAT_UPDATED,
    CHAT_DELETED,
    UNKNOWN,
}

data class CloudSyncEvent(
    val event: CloudSyncEventType,
    val chatId: String?,
    val title: String?,
    val isPinned: Boolean?,
    val model: String?,
    val updatedAt: Long?,
)

enum class ChatPeerEventType {
    MESSAGE_NEW,
    AI_START,
    AI_DELTA,
    AI_DONE,
    CHAT_UPDATED,
    CHAT_DELETED,
    UNKNOWN,
}

data class ChatPeerEvent(
    val event: ChatPeerEventType,
    val messageId: String?,
    val role: String?,
    val delta: String?,
    val content: String?,
)

@Serializable
data class RemoteDesktopStatus(
    val online: Boolean,
    val workspaces_count: Int = 0,
    val last_seen: Double? = null,
    val active_workspace: String? = null,
)

@Serializable
data class RemoteWorkspaceItem(
    val name: String,
    val path: String,
    val hasGit: Boolean? = null,
    val branch: String? = null,
)

@Serializable
data class RemoteDispatchResponse(
    val success: Boolean,
    val sessionId: String? = null,
    val status: String? = null,
    val message: String? = null,
)

data class RemoteStepEvent(
    val stepType: String,
    val toolName: String? = null,
    val message: String? = null,
    val stdout: String? = null,
    val stderr: String? = null,
    val timestamp: Long = System.currentTimeMillis(),
)

class CloudChatService private constructor(private val auth: AuthManager) {

    companion object {
        private const val BASE_URL = "https://api.newton.daniellimon.uk"

        @Volatile
        private var instance: CloudChatService? = null

        fun getInstance(authManager: AuthManager): CloudChatService {
            return instance ?: synchronized(this) {
                instance ?: CloudChatService(authManager).also { instance = it }
            }
        }
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS) // Infinite read timeout for SSE streams
        .build()

    private var globalSyncJob: Job? = null

    private fun makeRequestBuilder(endpoint: String): Request.Builder {
        val key = auth.nwtnKey
        require(key.isNotEmpty()) { "Authentication required." }
        return Request.Builder()
            .url("$BASE_URL$endpoint")
            .header("Authorization", "Bearer $key")
            .header("x-api-key", key)
            .header("Content-Type", "application/json")
            .header("User-Agent", "Newton-Android/2.2.0")
    }

    // 1. List Chats: GET /nwtn/chats
    suspend fun fetchChats(limit: Int = 100, offset: Int = 0): List<Conversation> = withContext(Dispatchers.IO) {
        val req = makeRequestBuilder("/nwtn/chats?limit=$limit&offset=$offset").get().build()
        val response = client.newCall(req).execute()
        if (!response.isSuccessful) return@withContext emptyList()

        val body = response.body?.string().orEmpty()
        val json = JSONObject(body)
        val chatsArr = json.optJSONArray("chats") ?: return@withContext emptyList()

        val list = mutableListOf<Conversation>()
        for (i in 0 until chatsArr.length()) {
            val c = chatsArr.getJSONObject(i)
            val cDate = (c.optDouble("created_at", System.currentTimeMillis() / 1000.0) * 1000).toLong()
            val uDate = (c.optDouble("updated_at", cDate / 1000.0) * 1000).toLong()
            list.add(
                Conversation(
                    id = c.getString("id"),
                    title = c.optString("title", "Newton Chat"),
                    provider = AIProvider.NEWTON,
                    modelId = c.optString("model", "Singularity"),
                    messages = emptyList(),
                    isPinned = c.optInt("is_pinned", 0) == 1,
                    isGhost = false,
                    createdAt = cDate,
                    updatedAt = uDate,
                )
            )
        }
        list
    }

    // 2. Create Chat: POST /nwtn/chats
    suspend fun createChat(title: String, model: String = "Singularity", systemPrompt: String? = null): Conversation =
        withContext(Dispatchers.IO) {
            val body = JSONObject().apply {
                put("title", title)
                put("model", model)
                if (!systemPrompt.isNullOrEmpty()) {
                    put("system_prompt", systemPrompt)
                }
            }
            val req = makeRequestBuilder("/nwtn/chats")
                .post(body.toString().toRequestBody("application/json".toMediaType()))
                .build()

            val response = client.newCall(req).execute()
            val bodyStr = response.body?.string().orEmpty()
            val json = JSONObject(bodyStr)
            val c = json.optJSONObject("chat") ?: JSONObject()

            val cDate = (c.optDouble("created_at", System.currentTimeMillis() / 1000.0) * 1000).toLong()
            val uDate = (c.optDouble("updated_at", cDate / 1000.0) * 1000).toLong()

            Conversation(
                id = c.optString("id", "chat_${System.currentTimeMillis()}"),
                title = c.optString("title", title),
                provider = AIProvider.NEWTON,
                modelId = c.optString("model", model),
                messages = emptyList(),
                isPinned = c.optInt("is_pinned", 0) == 1,
                isGhost = false,
                createdAt = cDate,
                updatedAt = uDate,
            )
        }

    // 3. Update Chat: PATCH /nwtn/chats/{id}
    suspend fun updateChat(id: String, title: String? = null, isPinned: Boolean? = null, model: String? = null) =
        withContext(Dispatchers.IO) {
            if (id.isEmpty()) return@withContext
            val body = JSONObject()
            if (title != null) body.put("title", title)
            if (isPinned != null) body.put("is_pinned", if (isPinned) 1 else 0)
            if (model != null) body.put("model", model)

            if (body.length() == 0) return@withContext
            val req = makeRequestBuilder("/nwtn/chats/$id")
                .patch(body.toString().toRequestBody("application/json".toMediaType()))
                .build()
            client.newCall(req).execute()
        }

    // 4. Delete Chat: DELETE /nwtn/chats/{id}
    suspend fun deleteChat(id: String) = withContext(Dispatchers.IO) {
        if (id.isEmpty()) return@withContext
        val req = makeRequestBuilder("/nwtn/chats/$id").delete().build()
        client.newCall(req).execute()
    }

    // 5. Fetch Messages: GET /nwtn/chats/{id}/messages
    suspend fun fetchMessages(chatId: String, limit: Int = 100): List<Message> = withContext(Dispatchers.IO) {
        if (chatId.isEmpty()) return@withContext emptyList()
        val req = makeRequestBuilder("/nwtn/chats/$chatId/messages?limit=$limit").get().build()
        val response = client.newCall(req).execute()
        if (!response.isSuccessful) return@withContext emptyList()

        val body = response.body?.string().orEmpty()
        val json = JSONObject(body)
        val msgsArr = json.optJSONArray("messages") ?: return@withContext emptyList()

        val list = mutableListOf<Message>()
        for (i in 0 until msgsArr.length()) {
            val m = msgsArr.getJSONObject(i)
            val date = (m.optDouble("created_at", System.currentTimeMillis() / 1000.0) * 1000).toLong()
            val role = when (m.optString("role", "assistant").lowercase()) {
                "user" -> MessageRole.USER
                "system" -> MessageRole.SYSTEM
                else -> MessageRole.ASSISTANT
            }
            list.add(
                Message(
                    id = m.getString("id"),
                    role = role,
                    content = m.optString("content", ""),
                    createdAt = date,
                    isStreaming = false,
                )
            )
        }
        list
    }

    // 6. Stream Chat Message: POST /nwtn/chats/{id}/messages?stream=true
    fun streamChatMessage(
        chatId: String,
        prompt: String,
        model: String = "Singularity",
        attachments: List<Pair<String, String>> = emptyList(), // Pair(type, data/url)
    ): Flow<String> = flow {
        val body = JSONObject().apply {
            put("prompt", prompt)
            put("model", model)
            if (attachments.isNotEmpty()) {
                val attArr = JSONArray()
                for (att in attachments) {
                    val attObj = JSONObject().apply {
                        put("type", att.first)
                        put("data", att.second)
                    }
                    attArr.put(attObj)
                }
                put("attachments", attArr)
            }
        }

        val req = makeRequestBuilder("/nwtn/chats/$chatId/messages?stream=true")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(req).execute()
        if (!response.isSuccessful) {
            val err = response.body?.string() ?: "HTTP ${response.code}"
            throw Exception("Server error (${response.code}): $err")
        }

        val creditsHeader = response.header("X-Credits-Left")
        creditsHeader?.toLongOrNull()?.let { auth.updateCreditsFromStream(it) }

        val source = response.body?.source() ?: return@flow
        val reader = BufferedReader(InputStreamReader(source.inputStream()))

        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val trimmed = line!!.trim()
            if (trimmed.startsWith("data: ")) {
                val payload = trimmed.substring(6).trim()
                if (payload == "[DONE]") {
                    break
                }
                try {
                    val json = JSONObject(payload)
                    if (json.has("credits_left")) {
                        auth.updateCreditsFromStream(json.optLong("credits_left"))
                    }
                    if (json.has("delta")) {
                        emit(json.getString("delta"))
                    } else if (json.has("error")) {
                        throw Exception(json.getString("error"))
                    }
                    if (json.optBoolean("done", false)) {
                        val reply = json.optString("reply", "")
                        if (reply.isNotEmpty()) {
                            emit(reply)
                        }
                        break
                    }
                } catch (_: Exception) {}
            }
        }
    }.flowOn(Dispatchers.IO)

    // 7. Global Sync Listener: GET /nwtn/sync/events
    fun startGlobalSyncListener(scope: CoroutineScope, onEvent: (CloudSyncEvent) -> Unit) {
        stopGlobalSyncListener()
        globalSyncJob = scope.launch(Dispatchers.IO) {
            while (isActive) {
                try {
                    if (!auth.isLoggedIn.value) {
                        kotlinx.coroutines.delay(3000)
                        continue
                    }
                    val req = makeRequestBuilder("/nwtn/sync/events").get().build()
                    val response = client.newCall(req).execute()
                    if (!response.isSuccessful) {
                        kotlinx.coroutines.delay(5000)
                        continue
                    }

                    val source = response.body?.source() ?: continue
                    val reader = BufferedReader(InputStreamReader(source.inputStream()))

                    var currentEventType: String? = null
                    var line: String?
                    while (isActive && reader.readLine().also { line = it } != null) {
                        val trimmed = line!!.trim()
                        if (trimmed.startsWith("event: ")) {
                            currentEventType = trimmed.substring(7).trim()
                        } else if (trimmed.startsWith("data: ")) {
                            val payload = trimmed.substring(6).trim()
                            if (currentEventType != null && payload.isNotEmpty()) {
                                try {
                                    val json = JSONObject(payload)
                                    val evType = when (currentEventType) {
                                        "chat:created" -> CloudSyncEventType.CHAT_CREATED
                                        "chat:updated" -> CloudSyncEventType.CHAT_UPDATED
                                        "chat:deleted" -> CloudSyncEventType.CHAT_DELETED
                                        else -> CloudSyncEventType.UNKNOWN
                                    }
                                    val syncEv = CloudSyncEvent(
                                        event = evType,
                                        chatId = json.optString("id").ifEmpty { json.optString("chat_id") },
                                        title = json.optString("title").takeIf { it.isNotEmpty() },
                                        isPinned = if (json.has("is_pinned")) json.optInt("is_pinned") == 1 else null,
                                        model = json.optString("model").takeIf { it.isNotEmpty() },
                                        updatedAt = json.optDouble("updated_at").takeIf { !it.isNaN() }?.let { (it * 1000).toLong() },
                                    )
                                    withContext(Dispatchers.Main) {
                                        onEvent(syncEv)
                                    }
                                } catch (_: Exception) {}
                            }
                            currentEventType = null
                        }
                    }
                } catch (_: Exception) {
                    kotlinx.coroutines.delay(5000)
                }
            }
        }
    }

    fun stopGlobalSyncListener() {
        globalSyncJob?.cancel()
        globalSyncJob = null
    }

    // 8. Stream Chat Peer Events: GET /nwtn/chats/{id}/events
    fun streamChatEvents(chatId: String): Flow<ChatPeerEvent> = flow {
        if (chatId.isEmpty()) return@flow
        val req = makeRequestBuilder("/nwtn/chats/$chatId/events").get().build()
        val response = client.newCall(req).execute()
        if (!response.isSuccessful) return@flow

        val source = response.body?.source() ?: return@flow
        val reader = BufferedReader(InputStreamReader(source.inputStream()))

        var currentEventType: String? = null
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val trimmed = line!!.trim()
            if (trimmed.startsWith("event: ")) {
                currentEventType = trimmed.substring(7).trim()
            } else if (trimmed.startsWith("data: ")) {
                val payload = trimmed.substring(6).trim()
                if (currentEventType != null && payload.isNotEmpty()) {
                    try {
                        val json = JSONObject(payload)
                        val evType = when (currentEventType) {
                            "message:new" -> ChatPeerEventType.MESSAGE_NEW
                            "ai:start" -> ChatPeerEventType.AI_START
                            "ai:delta" -> ChatPeerEventType.AI_DELTA
                            "ai:done" -> ChatPeerEventType.AI_DONE
                            "chat:updated" -> ChatPeerEventType.CHAT_UPDATED
                            "chat:deleted" -> ChatPeerEventType.CHAT_DELETED
                            else -> ChatPeerEventType.UNKNOWN
                        }
                        emit(
                            ChatPeerEvent(
                                event = evType,
                                messageId = json.optString("id").ifEmpty { json.optString("message_id") },
                                role = json.optString("role"),
                                delta = json.optString("delta"),
                                content = json.optString("content"),
                            )
                        )
                    } catch (_: Exception) {}
                }
                currentEventType = null
            }
        }
    }.flowOn(Dispatchers.IO)

    // 9. Desktop Remote Control API
    suspend fun fetchDesktopStatus(): RemoteDesktopStatus = withContext(Dispatchers.IO) {
        val req = makeRequestBuilder("/nwtn/desktop/status").get().build()
        val response = client.newCall(req).execute()
        if (!response.isSuccessful) return@withContext RemoteDesktopStatus(online = false)
        val json = JSONObject(response.body?.string().orEmpty())
        RemoteDesktopStatus(
            online = json.optBoolean("online", false),
            workspaces_count = json.optInt("workspaces_count", 0),
            last_seen = json.optDouble("last_seen").takeIf { !it.isNaN() },
            active_workspace = json.optString("active_workspace").takeIf { it.isNotEmpty() },
        )
    }

    suspend fun fetchDesktopWorkspaces(): List<RemoteWorkspaceItem> = withContext(Dispatchers.IO) {
        val req = makeRequestBuilder("/nwtn/desktop/workspaces").get().build()
        val response = client.newCall(req).execute()
        if (!response.isSuccessful) return@withContext emptyList()
        val json = JSONObject(response.body?.string().orEmpty())
        val arr = json.optJSONArray("workspaces") ?: return@withContext emptyList()
        val list = mutableListOf<RemoteWorkspaceItem>()
        for (i in 0 until arr.length()) {
            val item = arr.getJSONObject(i)
            list.add(
                RemoteWorkspaceItem(
                    name = item.optString("name", "Workspace"),
                    path = item.optString("path", ""),
                    hasGit = item.optBoolean("hasGit", false),
                    branch = item.optString("branch").takeIf { it.isNotEmpty() },
                )
            )
        }
        list
    }

    suspend fun dispatchDesktopCommand(workspacePath: String, task: String, model: String = "Singularity-Matrix"): RemoteDispatchResponse =
        withContext(Dispatchers.IO) {
            val body = JSONObject().apply {
                put("workspacePath", workspacePath)
                put("task", task)
                put("model", model)
            }
            val req = makeRequestBuilder("/nwtn/desktop/dispatch")
                .post(body.toString().toRequestBody("application/json".toMediaType()))
                .build()

            val response = client.newCall(req).execute()
            val json = JSONObject(response.body?.string().orEmpty())
            RemoteDispatchResponse(
                success = response.isSuccessful && json.optBoolean("success", true),
                sessionId = json.optString("sessionId").takeIf { it.isNotEmpty() },
                status = json.optString("status").takeIf { it.isNotEmpty() },
                message = json.optString("message").takeIf { it.isNotEmpty() },
            )
        }

    suspend fun cancelDesktopCommand(sessionId: String? = null) = withContext(Dispatchers.IO) {
        val ep = if (sessionId.isNullOrEmpty()) "/nwtn/desktop/cancel" else "/nwtn/desktop/cancel?sessionId=$sessionId"
        val req = makeRequestBuilder(ep).post("{}".toRequestBody("application/json".toMediaType())).build()
        client.newCall(req).execute()
    }

    fun streamDesktopSession(): Flow<RemoteStepEvent> = flow {
        val req = makeRequestBuilder("/nwtn/desktop/session/stream").get().build()
        val response = client.newCall(req).execute()
        if (!response.isSuccessful) return@flow

        val source = response.body?.source() ?: return@flow
        val reader = BufferedReader(InputStreamReader(source.inputStream()))

        var currentEventType: String? = null
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val trimmed = line!!.trim()
            if (trimmed.startsWith("event: ")) {
                currentEventType = trimmed.substring(7).trim()
            } else if (trimmed.startsWith("data: ")) {
                val payload = trimmed.substring(6).trim()
                if (payload.isNotEmpty()) {
                    try {
                        val json = JSONObject(payload)
                        emit(
                            RemoteStepEvent(
                                stepType = json.optString("stepType", currentEventType ?: "step"),
                                toolName = json.optString("toolName").takeIf { it.isNotEmpty() },
                                message = json.optString("message").takeIf { it.isNotEmpty() },
                                stdout = json.optString("stdout").takeIf { it.isNotEmpty() },
                                stderr = json.optString("stderr").takeIf { it.isNotEmpty() },
                            )
                        )
                    } catch (_: Exception) {}
                }
                currentEventType = null
            }
        }
    }.flowOn(Dispatchers.IO)
}
