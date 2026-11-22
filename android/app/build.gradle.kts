plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pocketspan.pocket_span"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pocketspan.pocket_span"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Create a versioned copy alongside Flutter's default release APK.
tasks.configureEach {
    if (name == "assembleRelease") {
        doLast {
            val versionName = project.findProperty("version-name")?.toString()
                ?: android.defaultConfig.versionName
                ?: "0.1.0"

            val flutterApkDir = file("../../build/app/outputs/flutter-apk")
            val releaseApkDir = file("${layout.buildDirectory.get()}/outputs/apk/release")
            val targetName = "PocketSpan_v${versionName}_release.apk"

            val defaultReleaseApk = file("$releaseApkDir/app-release.apk")
            if (defaultReleaseApk.exists()) {
                defaultReleaseApk.copyTo(file("$releaseApkDir/$targetName"), overwrite = true)
                flutterApkDir.mkdirs()
                defaultReleaseApk.copyTo(file("$flutterApkDir/$targetName"), overwrite = true)
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
