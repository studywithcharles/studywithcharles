// android/settings.gradle.kts

val flutterSdkPath = run {
    val properties = java.util.Properties()
    val localPropertiesFile = file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.inputStream())
    }
    val sdkFromProps = properties.getProperty("flutter.sdk")
    val sdkFromEnv = System.getenv("FLUTTER_ROOT") ?: System.getenv("FLUTTER_HOME")
    val flutterSdk = sdkFromProps ?: sdkFromEnv
    require(flutterSdk != null) {
        "flutter.sdk not set in local.properties and FLUTTER_ROOT/FLUTTER_HOME not set in environment"
    }
    flutterSdk
}

pluginManagement {
    includeBuild(File(flutterSdkPath, "packages/flutter_tools/gradle"))

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id.startsWith("com.android")) {
                useModule("com.android.tools.build:gradle:${requested.version}")
            }
            if (requested.id.id.startsWith("org.jetbrains.kotlin")) {
                useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")
            }
        }
    }
}

plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("dev.flutter.flutter-plugin-loader") version "1.0.0" apply false
}

include(":app")

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
    }
}