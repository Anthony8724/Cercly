import java.util.Base64
import java.util.Properties

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
    val isCerclyStaging = "CERCLY_STAGING=true" in dartDefineEntries
    val configuredSupabaseUrl = dartDefineEntries
        .firstOrNull { it.startsWith("SUPABASE_URL=") }
        ?.substringAfter("=")
    val configuredPublishableKey = dartDefineEntries
        .firstOrNull { it.startsWith("SUPABASE_PUBLISHABLE_KEY=") }
        ?.substringAfter("=")

    if (isCerclyStaging) {
        if (isUiEvaluation || isDemoRelease) {
            throw GradleException("CERCLY_STAGING no se combina con builds de evaluación/demo.")
        }
        if (configuredSupabaseUrl != "https://dlajxviqhkdcqnmczhvr.supabase.co") {
            throw GradleException("El APK STAGING requiere exclusivamente la URL de Supabase Staging.")
        }
        if (configuredPublishableKey.isNullOrBlank() ||
            !configuredPublishableKey.startsWith("sb_publishable_") ||
            dartDefineEntries.any {
                it.startsWith("SUPABASE_SERVICE_ROLE_KEY=") ||
                    it.startsWith("SUPABASE_SECRET_KEY=") ||
                    it.startsWith("DATABASE_URL=") ||
                    it.startsWith("DB_PASSWORD=") ||
                    it.startsWith("POSTGRES_PASSWORD=")
            }
        ) {
            throw GradleException("El APK STAGING requiere solo una clave publicable y no admite secretos de servidor.")
        }
    } else if (configuredSupabaseUrl == "https://dlajxviqhkdcqnmczhvr.supabase.co") {
        throw GradleException("La URL de Staging requiere CERCLY_STAGING para evitar un APK indistinguible de Production.")
    }

    if (isDemoRelease && !isUiEvaluation) {
        throw GradleException(
            "CERCLY_DEMO_RELEASE requiere CERCLY_UI_EVALUATION para impedir conexiones remotas.",
        )
    }
    if (isCerclyStaging) {
        defaultConfig {
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appLabel"] = "Cercly STAGING"
            manifestPlaceholders["authCallbackScheme"] = "com.cercly.cercly.staging"
        }
    } else if (isUiEvaluation) {
        defaultConfig {
            applicationIdSuffix = if (isDemoRelease) ".demo" else ".evaluation"
            manifestPlaceholders["appLabel"] = if (isDemoRelease) {
                "Cercly Demo v0.1.0"
            } else {
                "Cercly Evaluación"
            }
            manifestPlaceholders["authCallbackScheme"] = "com.cercly.cercly"
        }
    } else {
        defaultConfig {
            manifestPlaceholders["appLabel"] = "Cercly"
            manifestPlaceholders["authCallbackScheme"] = "com.cercly.cercly"
        }
    }

    val releaseKeyPropertiesFile = rootProject.file("key.properties")
    val releaseTaskRequested = gradle.startParameter.taskNames.any {
        it.contains("release", ignoreCase = true)
    }
    val releaseSigningConfig = if (releaseKeyPropertiesFile.isFile) {
        val releaseKeyProperties = Properties().apply {
            releaseKeyPropertiesFile.inputStream().use { load(it) }
        }
        val requiredReleaseKeyProperties = listOf(
            "storeFile",
            "storePassword",
            "keyAlias",
            "keyPassword",
        )
        val missingReleaseKeyProperties = requiredReleaseKeyProperties.filter {
            releaseKeyProperties.getProperty(it).isNullOrBlank()
        }
        if (missingReleaseKeyProperties.isNotEmpty()) {
            throw GradleException(
                "Faltan propiedades de firma release en android/key.properties: " +
                    missingReleaseKeyProperties.joinToString(", "),
            )
        }
        signingConfigs.create("release") {
            storeFile = rootProject.file(releaseKeyProperties.getProperty("storeFile"))
            storePassword = releaseKeyProperties.getProperty("storePassword")
            keyAlias = releaseKeyProperties.getProperty("keyAlias")
            keyPassword = releaseKeyProperties.getProperty("keyPassword")
        }
    } else {
        if (releaseTaskRequested) {
            throw GradleException(
                "Falta android/key.properties. Configura la clave privada de carga antes de compilar release.",
            )
        }
        null
    }

    buildTypes {
        release {
            signingConfig = releaseSigningConfig
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
