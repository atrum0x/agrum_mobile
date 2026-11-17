import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key: android/key.properties locally, or the CI workflow writes it from secrets.
// Without it, release builds fall back to the debug key so `flutter run --release` still works.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.containsKey("storeFile")

android {
    namespace = "com.atrum.agrum_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The prod app keeps the original id, so phones that already have the app keep their data.
        // dev and uat add a suffix below, so all three can be installed side by side.
        applicationId = "com.atrum.agrum_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // CL-07 (decided 2026-10-27): minimum Android 7.0. Pinned so a Flutter upgrade can't raise it
        // silently; review when the scale (CL-06) is chosen
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One app per backend: build with --flavor dev|uat|prod (pubspec default-flavor is dev).
    // Each flavor is a separate app on the phone with its own name, data, login and fingerprint key.
    // The backend URL still comes from --dart-define=API_BASE_URL (CI: the flavor's GitHub environment).
    flavorDimensions += "env"
    productFlavors {
        // Local `flutter run` only (CI builds uat and prod), so a debug build never replaces the
        // UAT app installed from Firebase
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Agrum DEV"
        }
        create("uat") {
            dimension = "env"
            applicationIdSuffix = ".uat"
            manifestPlaceholders["appLabel"] = "Agrum UAT"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appLabel"] = "Agrum"
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
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
