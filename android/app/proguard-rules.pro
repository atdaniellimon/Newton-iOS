# Newton Android — keep kotlinx-serialization companions and model names for cross-platform JSON.
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*
-keepclasseswithmembers class ai.newton.shared.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keepclassmembers class ai.newton.shared.** {
    *** Companion;
}
-keepclasseswithmembers class ai.newton.android.** {
    kotlinx.serialization.KSerializer serializer(...);
}
# OkHttp platform warnings
-dontwarn okhttp3.**
-dontwarn okio.**
