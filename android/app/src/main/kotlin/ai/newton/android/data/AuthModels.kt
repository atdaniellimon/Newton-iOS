package ai.newton.android.data

import kotlinx.serialization.Serializable

@Serializable
data class SubscriptionTierInfo(
    val id: String,
    val name: String,
    val badge: String,
    val priceMXN: Int,
    val rpmLimit: Int,
    val dailyImagesUsed: Int = 0,
    val dailyImagesLimit: String = "20",
    val allowedModels: List<String> = listOf("Singularity"),
    val features: List<String> = emptyList(),
    val expiresAt: Long? = null,
) {
    fun localizedFeatures(isSpanish: Boolean = true): List<String> {
        if (isSpanish) {
            return when (id.lowercase()) {
                "pro" -> listOf(
                    "Acceso a Singularity y Singularity-Matrix",
                    "50,000,000 tokens mensuales",
                    "Límite de velocidad de 180 RPM",
                    "100 generaciones de imágenes al día",
                    "600 solicitudes / ventana de 5 horas",
                    "7,500 mensajes semanales",
                )
                "matrix" -> listOf(
                    "Acceso ilimitado a todos los modelos (Singularity + Singularity-Matrix)",
                    "Ultra rendimiento: 600 RPM de tasa de procesamiento",
                    "250,000,000 tokens mensuales (25x Base / 5x Pro)",
                    "Generación ilimitada de imágenes diarias",
                    "Máxima prioridad en servidor y cola cero",
                    "Acceso anticipado a Orbits y herramientas experimentales",
                )
                else -> listOf(
                    "Acceso a Newton Singularity",
                    "10,000,000 tokens mensuales",
                    "Límite de velocidad de 60 RPM",
                    "20 generaciones de imágenes al día",
                    "200 solicitudes / ventana de 5 horas",
                    "1,500 mensajes semanales",
                )
            }
        }
        return features
    }

    fun canUseModel(modelId: String): Boolean {
        if (allowedModels.contains("*")) return true
        val target = modelId.lowercase()
        return allowedModels.any { allowed ->
            val a = allowed.lowercase()
            a == target || target.contains(a) || a.contains(target)
        }
    }

    companion object {
        val base = SubscriptionTierInfo(
            id = "base",
            name = "Newton Base",
            badge = "Base",
            priceMXN = 250,
            rpmLimit = 60,
            dailyImagesUsed = 0,
            dailyImagesLimit = "20",
            allowedModels = listOf("Singularity"),
            features = listOf(
                "Access to Newton Singularity",
                "10,000,000 monthly tokens",
                "60 RPM rate limit",
                "20 daily image generations",
                "200 requests / 5-hour window",
                "1,500 weekly messages",
            ),
        )

        val pro = SubscriptionTierInfo(
            id = "pro",
            name = "Newton Pro",
            badge = "Pro",
            priceMXN = 750,
            rpmLimit = 180,
            dailyImagesUsed = 0,
            dailyImagesLimit = "100",
            allowedModels = listOf("Singularity", "Singularity-Matrix"),
            features = listOf(
                "Access to Singularity and Singularity-Matrix",
                "50,000,000 monthly tokens",
                "180 RPM rate limit",
                "100 daily image generations",
                "600 requests / 5-hour window",
                "7,500 weekly messages",
            ),
        )

        val matrix = SubscriptionTierInfo(
            id = "matrix",
            name = "Newton Matrix",
            badge = "Matrix",
            priceMXN = 3000,
            rpmLimit = 600,
            dailyImagesUsed = 0,
            dailyImagesLimit = "unlimited",
            allowedModels = listOf("*"),
            features = listOf(
                "Unlimited access to all models (Singularity + Singularity-Matrix)",
                "Ultra performance: 600 RPM throughput",
                "250,000,000 monthly tokens (25x Base / 5x Pro)",
                "Unlimited daily image generations",
                "Highest server priority and zero queue",
                "Early access to Orbits and experimental tools",
            ),
        )
    }
}

@Serializable
data class QuotaWindow(
    val used: Int = 0,
    val limit: Int = 1,
    val resetAt: Long? = null,
) {
    val percent: Float
        get() = if (limit > 0) (used.toFloat() / limit.toFloat()).coerceIn(0f, 1f) else 0f
}

@Serializable
data class UsageAuditRecord(
    val timestamp: Long,
    val endpoint: String,
    val tokens: Int,
    val inputTokens: Int = 0,
    val outputTokens: Int = 0,
    val costTokens: Int = tokens,
    val status: Int = 200,
)
