import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun requiredKeystoreProperty(name: String): String {
    val value = keystoreProperties.getProperty(name)?.trim()
    check(!value.isNullOrEmpty()) {
        "android/key.properties must set a non-empty $name for release builds."
    }
    return value
}

android {
    namespace = "com.relayshell.relayshell"
    // Pinned rather than `flutter.compileSdkVersion` so the build does not
    // depend on whichever SDK platform happens to be installed. Raise this
    // deliberately, together with a device-test pass.
    // SDK Manager publishes this platform as android-37.0, so pin the minor
    // level explicitly rather than looking for the absent android-37 package.
    compileSdk {
        version = release(37) {
            minorApiLevel = 0
        }
    }
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.relayshell.relayshell"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseTaskRequested) {
                check(keystorePropertiesFile.exists()) {
                    "Missing android/key.properties. Release builds require a private upload key."
                }
                keyAlias = requiredKeystoreProperty("keyAlias")
                keyPassword = requiredKeystoreProperty("keyPassword")
                storePassword = requiredKeystoreProperty("storePassword")
                storeFile = file(requiredKeystoreProperty("storeFile")).also {
                    check(it.isFile) {
                        "The release keystore configured by android/key.properties does not exist."
                    }
                }
            } else if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let(::file)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
