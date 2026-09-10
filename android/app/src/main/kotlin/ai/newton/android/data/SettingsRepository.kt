package ai.newton.android.data

import ai.newton.shared.AIProvider
import ai.newton.shared.LLMService
import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.newtonPrefs by preferencesDataStore(name = "newton_settings")

/**
 * Android counterpart of Swift `SettingsManager`.
 *
 * Two deliberate differences from iOS (fixes, not ports):
 * 1. NO hardcoded tunnel URL — blank endpoint falls back to the provider default.
 * 2. API keys live ONLY in EncryptedSharedPreferences (Keystore), never in DataStore.
 */
class SettingsRepository(private val appContext: Context) {

    private val keys = object {
        val PROVIDER = stringPreferencesKey("currentProvider")
        val MODEL_ID = stringPreferencesKey("currentModelId")
        val BASE_URL = stringPreferencesKey("customBaseUrl")
        val THEME = stringPreferencesKey("appTheme")
    }

    val provider: Flow<AIProvider> = appContext.newtonPrefs.data
        .map { AIProvider.fromWire(it[keys.PROVIDER]) }

    val modelId: Flow<String> = appContext.newtonPrefs.data
        .map { it[keys.MODEL_ID] ?: AIProvider.OPENAI_COMPATIBLE.defaultModelId }

    val baseUrl: Flow<String> = appContext.newtonPrefs.data
        .map { it[keys.BASE_URL].orEmpty() }

    val theme: Flow<String> = appContext.newtonPrefs.data
        .map { it[keys.THEME] ?: "system" }

    suspend fun setProvider(provider: AIProvider) {
        appContext.newtonPrefs.edit { it[keys.PROVIDER] = provider.wireValue }
    }

    suspend fun setModelId(modelId: String) {
        appContext.newtonPrefs.edit { it[keys.MODEL_ID] = modelId }
    }

    suspend fun setBaseUrl(baseUrl: String) {
        appContext.newtonPrefs.edit { it[keys.BASE_URL] = baseUrl }
    }

    suspend fun setTheme(theme: String) {
        appContext.newtonPrefs.edit { it[keys.THEME] = theme }
    }

    suspend fun effectiveBaseUrl(provider: AIProvider): String =
        LLMService.effectiveBaseUrl(provider, baseUrl.first())

    //region API keys (EncryptedSharedPreferences = Android Keychain)

    private val encryptedPrefs by lazy {
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            appContext,
            "newton_secrets",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun getApiKey(provider: AIProvider): String =
        encryptedPrefs.getString("key_${provider.wireValue}", "").orEmpty()

    fun setApiKey(provider: AIProvider, key: String) {
        encryptedPrefs.edit().putString("key_${provider.wireValue}", key).apply()
    }

    //endregion
}
