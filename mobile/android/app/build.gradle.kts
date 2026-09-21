import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Carga las credenciales de firma desde android/key.properties si existe.
// Ese archivo NO se versiona (esta en .gitignore) porque contiene las
// contraseñas del keystore. Patron recomendado por la documentacion
// oficial de Flutter: https://docs.flutter.dev/deployment/android
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hayKeystore = keystorePropertiesFile.exists()
if (hayKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "ni.edu.unan.cosechaclima"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Antes era "com.example.mobile": el prefijo com.example esta
        // reservado para ejemplos y Google Play rechaza cualquier APK
        // que lo use. El applicationId es permanente una vez publicado.
        applicationId = "ni.edu.unan.cosechaclima"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Si existe android/key.properties se firma con el keystore
            // real. Si no, se cae a las claves de debug para que
            // `flutter run --release` siga funcionando en desarrollo.
            //
            // Un APK firmado con claves de debug NO sirve para
            // distribucion: la clave de debug es publica y compartida por
            // todos los SDK de Android, cualquiera puede re-firmar el APK
            // suplantando la app. Generá tu keystore antes del release
            // v1.0 -- ver mobile/README.md, seccion "Build de release".
            signingConfig = if (hayKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
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

flutter {
    source = "../.."
}
