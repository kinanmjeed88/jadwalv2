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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
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

        // 1. Try to load from Environment Variables
        val envStoreFile = System.getenv("STORE_FILE")
        val envStorePassword = System.getenv("STORE_PASSWORD")
        val envKeyAlias = System.getenv("KEY_ALIAS")
        val envKeyPassword = System.getenv("KEY_PASSWORD")

        val hasEnvVars = envStoreFile != null && envStorePassword != null && envKeyAlias != null && envKeyPassword != null

        // 2. Try to load from key.properties
        val hasPropertiesFile = keystorePropertiesFile.exists()

        if (hasPropertiesFile) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        }

        create("release") {
            if (hasEnvVars) {
                storeFile = file(envStoreFile!!)
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            } else if (hasPropertiesFile) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            } else {
                // If it's a release build and we don't have keys, we must fail.
                // We check if the task graph includes 'assembleRelease' or 'bundleRelease'
                // But during configuration phase, tasks might not be fully populated.
                // A simpler way is to just throw when the storeFile is accessed, but we can't easily do that.
                // Gradle tasks are available in gradle.startParameter.taskNames
                val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
                if (isReleaseBuild) {
                    throw GradleException("Release signing config requires either Environment Variables (STORE_FILE, STORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD) or android/key.properties file to exist.")
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
