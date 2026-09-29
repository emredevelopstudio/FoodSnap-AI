# AndroidX WorkManager & Room Database Reflection schützen
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Google Mobile Ads SDK
-keep public class com.google.android.gms.ads.** {
    public *;
}
-keep public class com.google.ads.** {
    public *;
}

# RevenueCat Purchases SDK
-keep class com.revenuecat.purchases.** { *; }

# TensorFlow Lite & MediaPipe GenAI / LiteRT-LM Native Bindings
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.ai.edge.** { *; }
-dontwarn com.google.ai.edge.**


# Google ML Kit Text Recognition: Nur das lateinische Modell ist eingebunden.
# Das Flutter-Plugin referenziert die optionalen Sprachpakete trotzdem → R8 "Missing class".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
