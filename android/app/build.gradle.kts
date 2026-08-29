import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties from android/key.properties (never committed — see .gitignore).
// Absent on machines without the release keystore — the release buildType below
// now FAILS LOUDLY in that case rather than silently falling back to debug
// signing (see that block's comment for why, and the opt-in escape hatch).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kudi.kudimata"
    // Pinned to 36, not flutter.compileSdkVersion (34 on this project's
    // Flutter version) — flutter_plugin_android_lifecycle (pulled in
    // transitively by camera/file_picker) requires compiling against 36+;
    // CI failed with "file_picker is currently compiled against android-34"
    // until this was pinned explicitly. compileSdk only affects which SDK
    // APIs are available at compile time, not runtime behavior — that's
    // targetSdk (left at flutter.targetSdkVersion, untouched) and minSdk.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kudi.kudimata"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore when key.properties is present (CI decodes
            // the keystore secret onto disk before this runs). Absent that, this
            // USED to fall back to debug signing silently — a local
            // `flutter build apk --release` with no keystore produced a
            // debug-signed .apk that installs, runs, and looks exactly like a
            // real release artifact, with nothing on screen or in the output
            // filename to tell them apart. That is the exact failure class this
            // project has shipped before (see AndroidManifest.xml's allowBackup
            // and release-INTERNET-permission comments for two prior incidents
            // in the same shape) — a plausible-looking wrong artifact instead
            // of a loud failure.
            //
            // Now: fail the build by default, naming the missing file. A
            // contributor who deliberately wants a debug-signed "release" build
            // (e.g. to test R8/shrinking locally without the production keystore)
            // must opt in explicitly via ALLOW_DEBUG_SIGNED_RELEASE=true, which
            // still prints an unmissable warning so the resulting artifact is
            // never mistaken for a real release.
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else if (System.getenv("ALLOW_DEBUG_SIGNED_RELEASE") == "true") {
                logger.warn(
                    "\n" + "!".repeat(72) +
                    "\n! DEBUG-SIGNED RELEASE BUILD (ALLOW_DEBUG_SIGNED_RELEASE=true)" +
                    "\n! ${keystorePropertiesFile.absolutePath} is missing, so this" +
                    "\n! 'release' build is signed with the DEBUG key, not the real" +
                    "\n! release keystore. It is NOT a release candidate — do not" +
                    "\n! upload it anywhere or mistake it for one." +
                    "\n" + "!".repeat(72) + "\n"
                )
                signingConfigs.getByName("debug")
            } else {
                throw GradleException(
                    "Release build requires ${keystorePropertiesFile.absolutePath}, which " +
                    "is missing on this machine (it holds the real release keystore " +
                    "credentials and is git-ignored — see android/.gitignore). Without it, " +
                    "this build would previously have fallen back to debug signing SILENTLY, " +
                    "producing a debug-signed .apk indistinguishable from a real release. " +
                    "Either: (1) provide key.properties + the release keystore it points to, or " +
                    "(2) if you deliberately want a debug-signed 'release' build for local " +
                    "testing (e.g. checking R8/shrinking behaviour), re-run with " +
                    "ALLOW_DEBUG_SIGNED_RELEASE=true set in the environment — that path still " +
                    "warns loudly so the artifact is never mistaken for a real release."
                )
            }
        }
        // R8/minification note for the next maintainer: this block sets no
        // `isMinifyEnabled`/`isShrinkResources` line, yet a real release build
        // DOES run R8 (build/app/outputs/mapping/release/mapping.txt comes out
        // with real class/method renaming — confirmed against a packaged
        // artifact, see .qa-audit/release-check.md §3). Flutter's Gradle plugin
        // is defaulting the release buildType to minified+shrunk for this
        // Flutter/AGP version even though nothing here asks for it explicitly.
        // There is also no project-level proguard-rules.pro in this module —
        // shrinking/keep-rules rely entirely on the consumer ProGuard rules
        // each plugin (camera, file_picker, local_auth, socket_io_client, dio,
        // flutter_secure_storage, …) bundles into its own AAR. That has worked
        // so far, but it means adding a new plugin, or a reflective/JNI call in
        // app code, with no rules of its own is a live risk of an R8 crash or
        // silent runtime break that only appears in the release variant.
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
