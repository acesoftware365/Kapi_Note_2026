import kotlin.io.println
import com.android.build.gradle.BaseExtension
import com.android.build.gradle.internal.crash.afterEvaluate
import kotlin.io.path.exists
import java.util.Properties
import java.io.FileInputStream



val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}


plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
//new code


//new code end






dependencies {
    implementation("com.google.firebase:firebase-analytics")
}


android {
    namespace = "com.liisgo.kapi.note"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
//new code
    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }
    // Define signing configurations

    //end new code
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            // You can set other Kotlin compiler options here if needed, for example:
            // freeCompilerArgs.add("-Xjsr305=strict")
            // languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9) // Example
        }
    }


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.liisgo.kapi.note"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
//new code
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it)}
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            //signingConfig = signingConfigs.getByName("debug")
            signingConfig = signingConfigs.getByName("release")

        }
    }
}

flutter {
    source = "../.."
}

// INICIO: Workaround específico para 'google_mobile_ads' Namespace not specified (Kotlin DSL)
// In your android/app/build.gradle.kts
/*
allprojects {
    // This block attempts to apply the namespace to the google_mobile_ads project
    // after it has been evaluated by Gradle.
    afterEvaluate {
        if (project.name == "google_mobile_ads") {
            try {
                // Access the 'android' extension in a way that's compatible with Kotlin DSL
                val androidExtension = project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
                if (androidExtension != null) {
                    if (androidExtension.namespace == null || androidExtension.namespace!!.isEmpty()) {
                        // It's generally safer to use the library's typical package name
                        // or a unique namespace derived from it if you are unsure.
                        // For google_mobile_ads, its manifest usually has
                        // package="com.google.android.gms.ads.identifier" or similar.
                        // A common safe namespace to set is often related to its group ID.
                        // Check the library's AndroidManifest.xml for its package attribute if unsure.
                        // Let's assume a common one for now, but verify this if possible.
                        androidExtension.namespace = "com.google.android.gms.ads.mobileads" // Example, verify this
                        println("INFO: Set namespace for ${project.name} to ${androidExtension.namespace}")
                    }
                } else {
                    println("WARNING: Could not find Android extension for project ${project.name} to set namespace.")
                }
            } catch (e: Exception) {
                println("ERROR: Failed to configure namespace for ${project.name}: ${e.message}")
            }
        }
    }

    // You might also have a configurations.all block here for resolution strategies
    // Keep it if it's there and serving a purpose.
    configurations.all {
        resolutionStrategy {
            // Your existing resolution strategies, e.g.:
            // force("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
        }
    }
}

 */
// Apply namespace to specific subprojects that need it
// This should be at the root level of your build.gradle.kts, not nested inside another block unless intended.
subprojects {
    afterEvaluate { subproject -> // Changed 'project' to 'subproject' for clarity within this scope
        if (subproject.name == "google_mobile_ads") {
            subproject.extensions.findByType(BaseExtension::class.java)?.let { androidExtension ->
                if (androidExtension.namespace == null || androidExtension.namespace!!.isEmpty()) {
                    // Try to find the package name from the library's AndroidManifest.xml
                    // This is a more robust way to get the intended namespace.
                    // However, accessing files directly during configuration can be tricky.
                    // For google_mobile_ads, a common namespace is related to its package structure.
                    // You might need to look inside the google_mobile_ads-3.1.0.aar or its sources
                    // to confirm its intended package name if "com.google.android.gms.ads" isn't working.
                    // A likely candidate is "com.google.android.gms.ads.mobileads" or just "com.google.android.gms.ads"
                    // Often, the package attribute in its AndroidManifest.xml is a good indicator.
                    val intendedNamespace = "com.google.android.gms.ads" // Start with this common one
                    androidExtension.namespace = intendedNamespace
                    println("INFO: Dynamically set namespace for ${subproject.name} to $intendedNamespace")
                }
            } ?: println("WARNING: Could not find Android extension for project ${subproject.name} to set namespace.")
        }
        // You can add more 'else if' blocks here for other problematic plugins
        // else if (subproject.name == "another_plugin_requiring_namespace") { ... }
    }
}
