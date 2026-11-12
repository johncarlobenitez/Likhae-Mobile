plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.likhae"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.likhae"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

// Keep Flutter's standard APK output and add a project-friendly release name.
val flutterApkOutputDirectory = layout.buildDirectory.dir("outputs/flutter-apk")
val copyReleaseApkAsLikhae = tasks.register("copyReleaseApkAsLikhae") {
    doLast {
        val outputDirectory = flutterApkOutputDirectory.get().asFile
        val releaseApk = outputDirectory.resolve("app-release.apk")
        if (releaseApk.isFile) {
            releaseApk.copyTo(outputDirectory.resolve("Likhae.apk"), overwrite = true)
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease") {
        finalizedBy(copyReleaseApkAsLikhae)
    }
}
