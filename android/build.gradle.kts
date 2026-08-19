import com.android.build.api.dsl.CommonExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force compileSdk = 36 on EVERY subproject, not just :app. app/build.gradle.kts
// pinning compileSdk=36 only fixed the :app module itself — third-party plugin
// modules (file_picker, camera, etc.) are separate Gradle subprojects that read
// Flutter's own bundled default (34 on this Flutter version) independently, via
// `flutter.compileSdkVersion` in their own build.gradle files, which an app-level
// override can't reach. CI kept failing with "file_picker is currently compiled
// against android-34" even after that fix — flutter_plugin_android_lifecycle
// (pulled in transitively by camera/file_picker) requires 36+. CommonExtension is
// the AGP-stable interface both ApplicationExtension and LibraryExtension
// implement, so this one block covers :app and every plugin module alike.
subprojects {
    afterEvaluate {
        extensions.findByType(CommonExtension::class.java)?.let { android ->
            android.compileSdk = 36
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
