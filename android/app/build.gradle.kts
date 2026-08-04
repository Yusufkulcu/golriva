import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FIREBASE: google-services eklentisi YALNIZCA config dosyasi varken uygulanir.
// Boylece google-services.json olmayan makinelerde (CI dahil) derleme kirilmaz;
// kullanici dosyayi ekleyince push otomatik devreye girer.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// RELEASE IMZALAMA: android/key.properties varsa oradan okunur.
// key.properties ve .jks dosyasi ASLA git'e girmez (.gitignore).
// Dosya yoksa (ornegin CI) release derleme debug anahtariyla imzalanir.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.golriva"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications java.time API kullanir → desugaring sart.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.golriva"
        // Firebase Messaging en az API 23 ister; Flutter varsayilani daha
        // dusukse 23'e yukselt.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release") // Play icin gercek imza
            } else {
                signingConfigs.getByName("debug") // CI / anahtarsiz makine
            }
            // R8 KAPALI: koruma kurallarina ragmen acilis cokmesi surdu —
            // kucultucu tumden devre disi (bedel: ~10MB daha buyuk paket).
            // Ileride tekrar acmak istersek once cokme logunu cozeriz.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // core library desugaring (flutter_local_notifications gereksinimi)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
