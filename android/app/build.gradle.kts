import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jadwal.jadwal_v2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.jadwal.jadwal_v2"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        val keystorePropertiesFile = rootProject.file("key.properties")
        val keystoreProperties = Properties()
        var hasValidPropertiesFile = false

        // 1. Try to load from key.properties first
        if (keystorePropertiesFile.exists()) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            val storeFileProp = keystoreProperties["storeFile"] as String?
            val storePasswordProp = keystoreProperties["storePassword"] as String?
            val keyAliasProp = keystoreProperties["keyAlias"] as String?
            val keyPasswordProp = keystoreProperties["keyPassword"] as String?

            if (!storeFileProp.isNullOrBlank() && !storePasswordProp.isNullOrBlank() && !keyAliasProp.isNullOrBlank() && !keyPasswordProp.isNullOrBlank()) {
                hasValidPropertiesFile = true
            }
        }

        // 2. Try to load from Environment Variables as fallback
        val envStoreFile = System.getenv("STORE_FILE")
        val envStorePassword = System.getenv("STORE_PASSWORD")
        val envKeyAlias = System.getenv("KEY_ALIAS")
        val envKeyPassword = System.getenv("KEY_PASSWORD")

        val hasValidEnvVars = !envStoreFile.isNullOrBlank() && !envStorePassword.isNullOrBlank() && !envKeyAlias.isNullOrBlank() && !envKeyPassword.isNullOrBlank()

        create("release") {
            if (hasValidPropertiesFile) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            } else if (hasValidEnvVars) {
                storeFile = file(envStoreFile!!)
                storePassword = envStorePassword!!
                keyAlias = envKeyAlias!!
                keyPassword = envKeyPassword!!
            } else {
                val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
                if (isReleaseBuild) {
                    throw GradleException("Release signing config requires either a valid android/key.properties file or Environment Variables (STORE_FILE, STORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD).")
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// 🚨 هذا هو الجزء الجديد لإجبار المكتبات على التوافق مع AGP 8.6.0
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.core:core:1.13.1")
    }
}
