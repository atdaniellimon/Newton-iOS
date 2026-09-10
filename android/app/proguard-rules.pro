# Newton Android — keep kotlinx-serialization companions and model names for cross-platform JSON.
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepclasseswithmembers class ai.newton.shared.** {
    kotlinx.serialization.KSerializer serializer(...);
}
