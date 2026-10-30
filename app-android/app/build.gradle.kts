import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// Release signing comes from the git-ignored keystore.properties (storeFile, storePassword,
// keyAlias, keyPassword). Without it release builds are left unsigned rather than signed with
// the debug key, so that no debug-signed release can reach anyone; CI builds them that way.
val keystore = rootProject.file("keystore.properties").takeIf { it.exists() }
    ?.let { file -> Properties().apply { file.inputStream().use(::load) } }

android {
    namespace = "app.getkeyper"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.getkeyper.private"
        minSdk = 27 // android.os.SharedMemory
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
