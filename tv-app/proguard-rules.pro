# Proguard rules for dTVSteams TV
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <methods>;
}
-keep class com.dtvsteams.catalog.** { *; }
-dontwarn org.jsoup.**
