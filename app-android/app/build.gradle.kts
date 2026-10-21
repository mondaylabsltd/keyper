import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// Release signing comes from the git-ignored keystore.properties (storeFile, storePassword,
// keyAlias, keyPassword); without it release builds use the debug key. Keyper keeps no data,
// so reinstalling under a different key loses nothing.
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
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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
}
