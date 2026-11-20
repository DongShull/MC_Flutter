plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.movieclaw.mc_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.movieclaw.mc_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Release 签名从环境变量读取（CI/本地注入）：
        //   MC_KEYSTORE_PATH / MC_KEYSTORE_PASSWORD / MC_KEY_ALIAS / MC_KEY_PASSWORD
        // 任一关键变量缺失时回落 debug 签名，保证构建不中断（正式发布需设置全部变量）。
        create("release") {
            val ksPath = System.getenv("MC_KEYSTORE_PATH")
            val ksPass = System.getenv("MC_KEYSTORE_PASSWORD")
            val envAlias = System.getenv("MC_KEY_ALIAS")
            val keyPass = System.getenv("MC_KEY_PASSWORD")
            if (ksPath != null && ksPass != null && envAlias != null && keyPass != null) {
                storeFile = file(ksPath)
                storePassword = ksPass
                keyAlias = envAlias
                keyPassword = keyPass
            } else {
                // Fallback: 使用 debug 签名（缺省回落，注释说明见上）。
                storeFile = signingConfigs.getByName("debug").storeFile
                storePassword = signingConfigs.getByName("debug").storePassword
                keyAlias = signingConfigs.getByName("debug").keyAlias
                keyPassword = signingConfigs.getByName("debug").keyPassword
            }
        }
    }

    buildTypes {
        release {
            // 使用上面的 release 签名配置（未设置环境变量时实际为 debug 密钥）。
            signingConfig = signingConfigs.getByName("release")
            // 代码压缩/资源收缩默认关闭；正式发布前可打开评估混淆影响。
            isMinifyEnabled = false
            isShrinkResources = false
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
