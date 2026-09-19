package ai.newton.android.data

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class AuthManager private constructor(private val appContext: Context) {

    companion object {
        const val API_BASE_URL = "https://api.newton.daniellimon.uk"
        private const val PREFS_FILE = "newton_auth_secrets"
        private const val KEY_TOKEN = "nwtn_key"
        private const val KEY_USER = "nwtn_username"

        @Volatile
        private var instance: AuthManager? = null

        fun getInstance(context: Context): AuthManager {
            return instance ?: synchronized(this) {
                instance ?: AuthManager(context.applicationContext).also { instance = it }
            }
        }
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val securePrefs: SharedPreferences by lazy {
        try {
            val masterKey = MasterKey.Builder(appContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                appContext,
                PREFS_FILE,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (_: Exception) {
            appContext.getSharedPreferences("newton_auth_fallback", Context.MODE_PRIVATE)
        }
    }

    private val _isLoggedIn = MutableStateFlow(false)
    val isLoggedIn: StateFlow<Boolean> = _isLoggedIn.asStateFlow()

    private val _username = MutableStateFlow("")
    val username: StateFlow<String> = _username.asStateFlow()

    private val _email = MutableStateFlow("")
    val email: StateFlow<String> = _email.asStateFlow()

    private val _emailVerified = MutableStateFlow(true)
    val emailVerified: StateFlow<Boolean> = _emailVerified.asStateFlow()

    private val _tier = MutableStateFlow(SubscriptionTierInfo.base)
    val tier: StateFlow<SubscriptionTierInfo> = _tier.asStateFlow()

    private val _creditsRemaining = MutableStateFlow(10_000_000L)
    val creditsRemaining: StateFlow<Long> = _creditsRemaining.asStateFlow()

    private val _creditsTotal = MutableStateFlow(10_000_000L)
    val creditsTotal: StateFlow<Long> = _creditsTotal.asStateFlow()

    private val _creditsUsed = MutableStateFlow(0L)
    val creditsUsed: StateFlow<Long> = _creditsUsed.asStateFlow()

    private val _trialEndsAt = MutableStateFlow<Long?>(null)
    val trialEndsAt: StateFlow<Long?> = _trialEndsAt.asStateFlow()

    private val _rpmLimit = MutableStateFlow(60)
    val rpmLimit: StateFlow<Int> = _rpmLimit.asStateFlow()

    private val _quotaReq5h = MutableStateFlow(QuotaWindow(used = 0, limit = 200))
    val quotaReq5h: StateFlow<QuotaWindow> = _quotaReq5h.asStateFlow()

    private val _quotaMsgsWeek = MutableStateFlow(QuotaWindow(used = 0, limit = 1500))
    val quotaMsgsWeek: StateFlow<QuotaWindow> = _quotaMsgsWeek.asStateFlow()

    private val _quotaTokensWeek = MutableStateFlow(QuotaWindow(used = 0, limit = 10_000_000))
    val quotaTokensWeek: StateFlow<QuotaWindow> = _quotaTokensWeek.asStateFlow()

    private val _recentUsageRecords = MutableStateFlow<List<UsageAuditRecord>>(emptyList())
    val recentUsageRecords: StateFlow<List<UsageAuditRecord>> = _recentUsageRecords.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private val _isRotatingKey = MutableStateFlow(false)
    val isRotatingKey: StateFlow<Boolean> = _isRotatingKey.asStateFlow()

    private val _lastKeyRotationMessage = MutableStateFlow<String?>(null)
    val lastKeyRotationMessage: StateFlow<String?> = _lastKeyRotationMessage.asStateFlow()

    init {
        val savedKey = securePrefs.getString(KEY_TOKEN, null)
        val savedUser = securePrefs.getString(KEY_USER, null)
        if (!savedKey.isNullOrEmpty() && savedKey.startsWith("ntwn-") && !savedUser.isNullOrEmpty()) {
            _isLoggedIn.value = true
            _username.value = savedUser
            CoroutineScope(Dispatchers.IO).launch {
                refreshUserInfo()
            }
        }
    }

    val nwtnKey: String
        get() = securePrefs.getString(KEY_TOKEN, "").orEmpty()

    suspend fun register(
        username: String,
        password: String,
        email: String? = null,
        tier: String = "base",
    ): Boolean = withContext(Dispatchers.IO) {
        val body = JSONObject().apply {
            put("username", username)
            put("password", password)
            put("tier", tier)
            if (!email.isNullOrBlank()) {
                put("email", email)
            }
        }
        performAuth("/auth/register", body)
    }

    suspend fun login(username: String, password: String): Boolean = withContext(Dispatchers.IO) {
        val body = JSONObject().apply {
            put("username", username)
            put("password", password)
        }
        performAuth("/auth/login", body)
    }

    suspend fun refreshUserInfo() = withContext(Dispatchers.IO) {
        val key = nwtnKey
        if (key.isEmpty()) return@withContext

        try {
            val req = Request.Builder()
                .url("$API_BASE_URL/auth/me")
                .header("Authorization", "Bearer $key")
                .header("x-api-key", key)
                .build()

            val response = client.newCall(req).execute()
            if (!response.isSuccessful) return@withContext

            val bodyString = response.body?.string() ?: return@withContext
            val json = JSONObject(bodyString)

            json.optString("username").takeIf { it.isNotEmpty() }?.let { u ->
                _username.value = u
                securePrefs.edit().putString(KEY_USER, u).apply()
            }
            json.optString("email").takeIf { it.isNotEmpty() }?.let { _email.value = it }
            if (json.has("email_verified")) {
                _emailVerified.value = json.optBoolean("email_verified", true)
            }
            if (json.has("rpm_limit")) {
                _rpmLimit.value = json.optInt("rpm_limit", 60)
            }

            // Credits
            val creditsObj = json.optJSONObject("credits")
            if (creditsObj != null) {
                _creditsTotal.value = creditsObj.optLong("total", 10_000_000L)
                _creditsUsed.value = creditsObj.optLong("used", 0L)
                _creditsRemaining.value = creditsObj.optLong("remaining", _creditsTotal.value - _creditsUsed.value)
            } else if (json.has("credits_left")) {
                _creditsRemaining.value = json.optLong("credits_left", 10_000_000L)
            }

            // Tier
            val tDict = json.optJSONObject("tier")
            if (tDict != null) {
                val tierId = tDict.optString("id", "base").lowercase()
                var currentTier = when (tierId) {
                    "matrix" -> SubscriptionTierInfo.matrix
                    "pro" -> SubscriptionTierInfo.pro
                    else -> SubscriptionTierInfo.base
                }
                if (tDict.has("name")) currentTier = currentTier.copy(name = tDict.getString("name"))
                if (tDict.has("badge")) currentTier = currentTier.copy(badge = tDict.getString("badge"))
                if (tDict.has("price_mxn")) currentTier = currentTier.copy(priceMXN = tDict.getInt("price_mxn"))
                if (tDict.has("rpm_limit")) currentTier = currentTier.copy(rpmLimit = tDict.getInt("rpm_limit"))

                val allowedArr = tDict.optJSONArray("allowed_models")
                if (allowedArr != null) {
                    val allowedList = mutableListOf<String>()
                    for (i in 0 until allowedArr.length()) {
                        allowedList.add(allowedArr.getString(i))
                    }
                    currentTier = currentTier.copy(allowedModels = allowedList)
                }

                val featuresArr = tDict.optJSONArray("features")
                if (featuresArr != null) {
                    val featuresList = mutableListOf<String>()
                    for (i in 0 until featuresArr.length()) {
                        featuresList.add(featuresArr.getString(i))
                    }
                    currentTier = currentTier.copy(features = featuresList)
                }

                if (tDict.has("expires_at") && !tDict.isNull("expires_at")) {
                    val exp = tDict.optLong("expires_at") * 1000L
                    currentTier = currentTier.copy(expiresAt = exp)
                    _trialEndsAt.value = exp
                }

                val dailyImages = tDict.optJSONObject("daily_images")
                if (dailyImages != null) {
                    val used = dailyImages.optInt("used", 0)
                    val limit = if (dailyImages.has("remaining")) {
                        dailyImages.optString("remaining", "20")
                    } else {
                        dailyImages.optString("limit", "20")
                    }
                    currentTier = currentTier.copy(dailyImagesUsed = used, dailyImagesLimit = limit)
                }
                _tier.value = currentTier
            }

            // Quotas
            val q = json.optJSONObject("quotas")
            if (q != null) {
                q.optJSONObject("req_5h")?.let { r ->
                    _quotaReq5h.value = QuotaWindow(
                        used = r.optInt("used", 0),
                        limit = r.optInt("limit", 200),
                        resetAt = r.optLong("reset_at").takeIf { it > 0 }?.times(1000L),
                    )
                }
                q.optJSONObject("msgs_week")?.let { m ->
                    _quotaMsgsWeek.value = QuotaWindow(
                        used = m.optInt("used", 0),
                        limit = m.optInt("limit", 1500),
                        resetAt = m.optLong("reset_at").takeIf { it > 0 }?.times(1000L),
                    )
                }
                q.optJSONObject("tokens_week")?.let { t ->
                    _quotaTokensWeek.value = QuotaWindow(
                        used = t.optInt("used", 0),
                        limit = t.optInt("limit", 10_000_000),
                        resetAt = t.optLong("reset_at").takeIf { it > 0 }?.times(1000L),
                    )
                }
            }
        } catch (_: Exception) {
            // Keep last cached values
        }
    }

    suspend fun rotateApiKey(): Pair<Boolean, String> = withContext(Dispatchers.IO) {
        val key = nwtnKey
        if (key.isEmpty()) return@withContext Pair(false, "No API key found")

        _isRotatingKey.value = true
        try {
            val req = Request.Builder()
                .url("$API_BASE_URL/auth/rotate-key")
                .post("{}".toRequestBody("application/json".toMediaType()))
                .header("Authorization", "Bearer $key")
                .header("x-api-key", key)
                .build()

            val response = client.newCall(req).execute()
            val bodyString = response.body?.string() ?: ""
            val json = JSONObject(bodyString)

            if (response.isSuccessful && json.optBoolean("ok", true)) {
                val newKey = json.optString("api_key")
                if (newKey.startsWith("ntwn-")) {
                    securePrefs.edit().putString(KEY_TOKEN, newKey).apply()
                    val msg = json.optString("message", "API Key rotated successfully.")
                    _lastKeyRotationMessage.value = msg
                    return@withContext Pair(true, msg)
                }
            }
            val err = json.optString("message", "Failed to rotate key")
            Pair(false, err)
        } catch (e: Exception) {
            Pair(false, e.message ?: "Connection error")
        } finally {
            _isRotatingKey.value = false
        }
    }

    suspend fun fetchUsageHistory(days: Int = 7) = withContext(Dispatchers.IO) {
        val key = nwtnKey
        if (key.isEmpty()) return@withContext

        try {
            val req = Request.Builder()
                .url("$API_BASE_URL/nwtn/usage/history?days=$days&limit=30")
                .header("Authorization", "Bearer $key")
                .header("x-api-key", key)
                .build()

            val response = client.newCall(req).execute()
            if (!response.isSuccessful) return@withContext
            val bodyString = response.body?.string() ?: return@withContext
            val json = JSONObject(bodyString)
            val recordsArr = json.optJSONArray("records") ?: return@withContext

            val list = mutableListOf<UsageAuditRecord>()
            for (i in 0 until recordsArr.length()) {
                val dict = recordsArr.getJSONObject(i)
                list.add(
                    UsageAuditRecord(
                        timestamp = dict.optLong("timestamp") * 1000L,
                        endpoint = dict.optString("endpoint", "/nwtn/chat"),
                        tokens = dict.optInt("tokens", 0),
                        inputTokens = dict.optInt("input_tokens", 0),
                        outputTokens = dict.optInt("output_tokens", 0),
                        costTokens = dict.optInt("cost_tokens", dict.optInt("tokens", 0)),
                        status = dict.optInt("status", 200),
                    )
                )
            }
            _recentUsageRecords.value = list
        } catch (_: Exception) {}
    }

    fun updateCreditsFromStream(newCreditsRemaining: Long) {
        _creditsRemaining.value = newCreditsRemaining
    }

    fun updateDailyImagesFromStream(used: Int, limit: String? = null) {
        val current = _tier.value
        _tier.value = current.copy(
            dailyImagesUsed = used,
            dailyImagesLimit = limit ?: current.dailyImagesLimit
        )
    }

    fun logout() {
        val key = nwtnKey
        if (key.isNotEmpty()) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val req = Request.Builder()
                        .url("$API_BASE_URL/auth/logout")
                        .post("{}".toRequestBody("application/json".toMediaType()))
                        .header("Authorization", "Bearer $key")
                        .header("x-api-key", key)
                        .build()
                    client.newCall(req).execute()
                } catch (_: Exception) {}
            }
        }

        securePrefs.edit().clear().apply()
        _isLoggedIn.value = false
        _username.value = ""
        _email.value = ""
        _creditsTotal.value = 0L
        _creditsUsed.value = 0L
        _creditsRemaining.value = 0L
        _trialEndsAt.value = null
        _tier.value = SubscriptionTierInfo.base
        _quotaReq5h.value = QuotaWindow(used = 0, limit = 200)
        _quotaMsgsWeek.value = QuotaWindow(used = 0, limit = 1500)
        _quotaTokensWeek.value = QuotaWindow(used = 0, limit = 10_000_000)
        _recentUsageRecords.value = emptyList()
        _lastError.value = null
    }

    private suspend fun performAuth(endpoint: String, body: JSONObject): Boolean {
        _isLoading.value = true
        _lastError.value = null

        return try {
            val mediaType = "application/json".toMediaType()
            val reqBody = body.toString().toRequestBody(mediaType)
            val req = Request.Builder()
                .url("$API_BASE_URL$endpoint")
                .post(reqBody)
                .build()

            val response = client.newCall(req).execute()
            val bodyString = response.body?.string().orEmpty()

            val json = try {
                JSONObject(bodyString)
            } catch (_: Exception) {
                _lastError.value = "Respuesta inválida del servidor"
                return false
            }

            if (json.has("error")) {
                val errObj = json.optJSONObject("error")
                _lastError.value = errObj?.optString("message") ?: json.optString("error")
                return false
            }

            if (json.has("detail")) {
                _lastError.value = json.optString("detail")
                return false
            }

            if (response.isSuccessful) {
                val key = json.optString("api_key").ifEmpty { json.optString("nwtn_key") }
                val user = json.optString("username")

                if (key.startsWith("ntwn-") && user.isNotEmpty()) {
                    securePrefs.edit()
                        .putString(KEY_TOKEN, key)
                        .putString(KEY_USER, user)
                        .apply()

                    _isLoggedIn.value = true
                    _username.value = user
                    if (json.has("email")) _email.value = json.optString("email")
                    if (json.has("credits_left")) _creditsRemaining.value = json.optLong("credits_left")

                    val tDict = json.optJSONObject("tier")
                    if (tDict != null) {
                        val tid = tDict.optString("id", "base").lowercase()
                        _tier.value = when (tid) {
                            "matrix" -> SubscriptionTierInfo.matrix
                            "pro" -> SubscriptionTierInfo.pro
                            else -> SubscriptionTierInfo.base
                        }
                    }

                    refreshUserInfo()
                    return true
                }
            }

            _lastError.value = "Error del servidor (${response.code})"
            false
        } catch (e: Exception) {
            _lastError.value = "Error de conexión: ${e.message}"
            false
        } finally {
            _isLoading.value = false
        }
    }
}
