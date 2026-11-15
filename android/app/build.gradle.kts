import com.android.build.api.variant.LibraryAndroidComponentsExtension

buildscript {
    if (file("google-services.json").isFile) {
        repositories {
            google()
            mavenCentral()
        }
        dependencies {
            classpath("com.google.gms:google-services:4.4.4")
        }
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

val appCompileSdk = flutter.compileSdkVersion

android {
    namespace = "com.example.todago_flutter"
    compileSdk = appCompileSdk
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.todago_flutter"
        minSdk = flutter.minSdkVersion                          // ← changed from flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Some Flutter plugins declare an older compile SDK than their Android dependencies require.
rootProject.subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.getByType<LibraryAndroidComponentsExtension>().finalizeDsl { library ->
            library.compileSdk = maxOf(library.compileSdk ?: 0, appCompileSdk)
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

dependencies {
    implementation("com.google.android.gms:play-services-maps:20.0.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
