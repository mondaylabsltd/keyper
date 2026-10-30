plugins {
    alias(libs.plugins.android.test)
}

// Keyper's clipboard clearing with Keyper in the background, its process cached, frozen or killed,
// as on a real phone. These tests cannot live in :app's androidTest: that APK's instrumentation runs
// inside Keyper's own process, which the system then never caches, freezes or kills. This APK
// instruments itself, so Keyper runs as an ordinary app beside it, driven through UiAutomation.
android {
    namespace = "app.getkeyper.backgroundtest"
    compileSdk = 36
    targetProjectPath = ":app"

    defaultConfig {
        minSdk = 27
        targetSdk = 36
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    @Suppress("UnstableApiUsage")
    experimentalProperties["android.experimental.self-instrumenting"] = true

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(libs.junit)
    implementation(libs.androidx.test.runner)
    implementation(libs.androidx.test.ext.junit)
}
