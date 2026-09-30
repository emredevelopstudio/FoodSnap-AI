import java.util.Base64
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Gemini-Konfiguration aus ../.env automatisch als --dart-define an Flutter geben,
// damit einfaches `flutter run` / `flutter build` funktioniert (ohne --dart-define-from-file).
// - Per Kommandozeile übergebene Werte haben Vorrang.
// - Mit GEMINI_PROXY_URL (Play-Store-Build) wird KEIN Key eingebaut.
run {
    val envFile = rootProject.file("../.env")
    if (!envFile.exists()) return@run

    // Import oben nötig: im Gradle-Skript ist `java` die Java-Extension, nicht das Paket.
    val decoder = Base64.getDecoder()
    val encoder = Base64.getEncoder()
    val existing = project.findProperty("dart-defines")?.toString()
        ?.split(",")?.filter { it.isNotBlank() } ?: emptyList()
    val existingNames = existing
        .map { String(decoder.decode(it)).substringBefore("=").trim() }
        .toSet()
    if ("GEMINI_PROXY_URL" in existingNames) return@run

    val fromEnv = envFile.readLines()
        .map { it.removePrefix("﻿").trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .filter { it.substringBefore("=").trim() !in existingNames }
        .map { encoder.encodeToString(it.toByteArray()) }

    if (fromEnv.isNotEmpty()) {
        project.extensions.extraProperties["dart-defines"] =
            (existing + fromEnv).joinToString(",")
    }
}

android {
    namespace = "com.foodsnap.ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "com.foodsnap.ai"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}


flutter {
    source = "../.."
}