plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.campus.rideshare"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.campus.rideshare"   // ✅ Kotlin DSL uses '='
        minSdk = flutter.minSdkVersion                              // ✅ minSdkVersion -> minSdk
        targetSdk = 34                           // ✅ targetSdkVersion -> targetSdk
        versionCode = flutter.versionCode        // ✅ Kotlin DSL property
        versionName = flutter.versionName        // ✅ Kotlin DSL property
    }

    buildTypes {
        getByName("release") {
            // 🔧 FIX: Kotlin DSL syntax
            // signingConfig = signingConfigs.getByName("release")  // uncomment if you have a release keystore
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
