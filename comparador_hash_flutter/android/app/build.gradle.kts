plugins {
    id("com.android.application")
    // O AGP 9 gerencia o Kotlin embutido quando aplicado junto ao plugin do Flutter.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.comparadorhash.comparador_hash"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.comparadorhash.comparador_hash"
        // minSdk 24+ garante suporte nativo ao ART MultiDex e às APIs de drag-and-drop.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Habilita explicitamente o modo MultiDex para compatibilidade total em builds DEX.
        multiDexEnabled = true
    }

    buildTypes {
        release {
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
