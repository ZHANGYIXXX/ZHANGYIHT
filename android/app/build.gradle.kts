plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.yizhanghe"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // 关键修复：华为/HarmonyOS 的 ART 无法直接从 APK 加载「压缩」的 .so，
    // 会导致 libflutter.so 加载失败、打开即闪退（进程直接死亡，无红屏）。
    // useLegacyPackaging=true 让原生库安装时解压到 app 私有目录，规避该问题；对其他机型无副作用。
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.yizhanghe"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 固定签名：仓库内 ci/release.p12.b64 解码得到 release.p12（CI 出包流程写入 android/app/）。
        // 直接硬编码已知常量，避免在 AGP 9.0 / Gradle Kotlin DSL 脚本里引用 java.util.Properties
        // （该上下文下 java.util 包无法解析，会导致整条编译失败）。
        // 所有出包统一使用同一把固定签名 → 手机可直接覆盖安装，无需卸载旧版。
        create("release") {
            storeFile = file("release.p12")
            storePassword = "yizhanghe-release-2026"
            keyAlias = "yizhanghe"
            keyPassword = "yizhanghe-release-2026"
            storeType = "pkcs12"
        }
    }

    buildTypes {
        release {
            // 所有出包统一使用同一把固定签名 → 手机可直接覆盖安装，无需卸载旧版。
            signingConfig = signingConfigs.getByName("release")
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
