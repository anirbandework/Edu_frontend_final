import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing — DROP IN A KEYSTORE LATER, NO CODE CHANGE NEEDED:
//   1) create a keystore:   keytool -genkey -v -keystore ~/eduassist-release.jks \
//                             -keyalg RSA -keysize 2048 -validity 10000 -alias eduassist
//   2) create android/key.properties (GIT-IGNORED) with:
//        storeFile=/absolute/path/to/eduassist-release.jks
//        storePassword=...
//        keyAlias=eduassist
//        keyPassword=...
// Until key.properties exists, release falls back to debug signing (so `flutter run
// --release` still works locally) — but a Play-Store artifact MUST be release-signed.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // TODO(release): set a real, unique application id + namespace, e.g.
    //   namespace = "com.yourcompany.eduassist"  (and applicationId to match)
    namespace = "com.example.edu_assist_dynamic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO(release): Specify your own unique Application ID.
        applicationId = "com.example.edu_assist_dynamic"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real release keystore once key.properties is present; otherwise
            // fall back to debug signing so local `--release` runs still work.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
