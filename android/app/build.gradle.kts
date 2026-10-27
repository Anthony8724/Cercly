import java.util.Base64

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cercly.cercly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cercly.cercly"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val dartDefineEntries: List<String> = (project.findProperty("dart-defines") as? String)
        .orEmpty()
        .split(",")
        .mapNotNull { entry: String ->
            runCatching<String> {
                String(Base64.getDecoder().decode(entry))
            }.getOrNull()
        }
    val isUiEvaluation = "CERCLY_UI_EVALUATION=true" in dartDefineEntries
    val isDemoRelease = "CERCLY_DEMO_RELEASE=true" in dartDefineEntries
    if (isDemoRelease && !isUiEvaluation) {
        throw GradleException(
            "CERCLY_DEMO_RELEASE requiere CERCLY_UI_EVALUATION para impedir conexiones remotas.",
        )
    }
    if (isUiEvaluation) {
        defaultConfig {
            applicationIdSuffix = if (isDemoRelease) ".demo" else ".evaluation"
            manifestPlaceholders["appLabel"] = if (isDemoRelease) {
                "Cercly Demo v0.1.0"
            } else {
                "Cercly Evaluación"
            }
        }
    } else {
        defaultConfig {
            manifestPlaceholders["appLabel"] = "Cercly"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4",
    )
}
