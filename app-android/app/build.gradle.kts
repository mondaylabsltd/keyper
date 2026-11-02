import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// Release signing comes from the git-ignored keystore.properties (storeFile, storePassword,
// keyAlias, keyPassword). Without it release builds are left unsigned rather than signed with
// the debug key, so that no debug-signed release can reach anyone; CI builds them that way.
val keystore = rootProject.file("keystore.properties").takeIf { it.exists() }
    ?.let { file -> Properties().apply { file.inputStream().use(::load) } }

// Providers make Git changes invalidate Gradle's configuration cache as well as the APK.
val gitCommit = providers.exec {
    workingDir(rootProject.projectDir)
    commandLine("git", "rev-parse", "--short=12", "HEAD")
}.standardOutput.asText.get().trim()
val gitDirty = providers.exec {
    workingDir(rootProject.projectDir)
    commandLine("git", "status", "--porcelain", "--untracked-files=normal")
}.standardOutput.asText.get().isNotBlank()
val buildRevision = gitCommit + if (gitDirty) "-dirty" else ""

android {
    namespace = "app.getkeyper"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.getkeyper.private"
        minSdk = 27 // android.os.SharedMemory
        targetSdk = 36
        versionCode = 2
        versionName = "1.0.1"
        buildConfigField("String", "BUILD_REVISION", "\"$buildRevision\"")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures { buildConfig = true }

    // Both languages must be available offline. Play's language splits can omit Chinese
    // on English devices, leaving the in-app language switch without its resources.
    bundle {
        language {
            enableSplit = false
        }
    }

    signingConfigs {
        if (keystore != null) create("release") {
            storeFile = rootProject.file(keystore.getProperty("storeFile"))
            storePassword = keystore.getProperty("storePassword")
            keyAlias = keystore.getProperty("keyAlias")
            keyPassword = keystore.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            optimization {
                enable = true
            }
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":core"))
    testImplementation(libs.junit)
    // The instrumented tests that back the website's claims (src/androidTest). Test APK only:
    // the app itself still depends on nothing but :core.
    androidTestImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.espresso.core)
}

// The clipboard tests that need Keyper's process frozen and killed live in :backgroundtest, whose
// instrumentation runs beside Keyper rather than inside it; they run with this task, so that one
// command (and CI) covers both.
tasks.matching { it.name == "connectedDebugAndroidTest" }.configureEach {
    finalizedBy(":backgroundtest:connectedDebugAndroidTest")
}
