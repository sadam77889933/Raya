plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yourname.quran_circle_report"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yourname.quran_circle_report"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // تعطيل مؤقت لتقليص/تعتيم الكود (R8): AGP 9.0.1 يفشل في العثور على
            // ملف proguard الافتراضي الخاص به داخلياً عند تفعيل minify ضمنياً
            // (Supplied proguard configuration does not exist:
            // .../proguard-android-optimize.txt-9.0.1) - خلل واضح في نسخة AGP
            // الحديثة جداً هذه، وليس في إعدادات المشروع. الأثر: حجم APK أكبر
            // قليلاً بلا تصغير/تعتيم للكود، لكن البناء يعمل. يمكن إعادة تفعيل
            // isMinifyEnabled لاحقاً عند إصلاح الخلل في إصدار أحدث من AGP، أو
            // عند تعريف قواعد proguard مخصّصة صراحةً بدل الاعتماد على ملف AGP
            // الافتراضي.
            isMinifyEnabled = false
            // AGP/إضافة Flutter Gradle Plugin يُفعّلان shrinkResources
            // افتراضياً لبنية الإصدار حتى لو لم يُذكَر هنا صراحة - وهذا
            // يتطلب إلزامياً تفعيل تقليص الكود (isMinifyEnabled) لأن تقليص
            // الموارد غير المستخدَمة يعتمد عليه لمعرفة ما هو "غير مستخدَم"
            // فعلياً. بما أن isMinifyEnabled معطَّل أعلاه (بسبب خلل AGP
            // 9.0.1 الموضَّح)، لازم تعطيل هذا أيضاً صراحةً وإلا يفشل البناء
            // بتعارض "Removing unused resources requires unused code
            // shrinking to be turned on".
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
