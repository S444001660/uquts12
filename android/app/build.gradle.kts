// --- تعريف الإضافات (Plugins) المستخدمة في عملية البناء ---
plugins {
    // الإضافة الأساسية لبناء تطبيق أندرويد.
    id("com.android.application")
    // إضافة خدمات جوجل (Google Services) الضرورية لربط التطبيق بـ Firebase.
    id("com.google.gms.google-services")
    // إضافة لدعم لغة Kotlin.
    id("kotlin-android")
    // إضافة خاصة بفلاتر لدمج وإدارة عملية البناء مع Gradle.
    id("dev.flutter.flutter-gradle-plugin")
}

//------------------------------------------------------------------------------

// --- الإعدادات الخاصة بنظام أندرويد ---
android {
    // مساحة الاسم (Namespace) للتطبيق، وهي معرف فريد للكود المصدر.
    namespace = "com.example.uquts1"
    // إصدار الـ SDK الذي يتم بناء التطبيق مقابله.
    compileSdk = 35
    // إصدار حزمة أدوات التطوير الأصلية (NDK) المستخدمة.
    ndkVersion = "27.0.12077973"

    //--------------------------------------------------------------------------

    // خيارات بناء الكود (Compilation).
    compileOptions {
        // تحديد توافق الكود المصدري مع إصدار Java 8.
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    // خيارات خاصة بلغة Kotlin.
    kotlinOptions {
        // تحديد أن الكود الناتج يجب أن يكون متوافقًا مع JVM 1.8.
        jvmTarget = "1.8"
    }

    //--------------------------------------------------------------------------

    // الإعدادات الافتراضية التي تنطبق على جميع أنواع البناء (debug, release).
    defaultConfig {
        // المعرف الفريد للتطبيق في متجر Google Play.
        applicationId = "com.example.uquts1"
        // أقل إصدار من نظام أندرويد يمكن للتطبيق العمل عليه.
        minSdk = 21
        // الإصدار المستهدف من نظام أندرويد الذي تم اختبار التطبيق عليه.
        targetSdk = 34
        // رقم إصدار التطبيق (يجب زيادته مع كل تحديث يتم رفعه للمتجر).
        versionCode = 1
        // اسم إصدار التطبيق الذي يراه المستخدم.
        versionName = "1.0"
        // تفعيل دعم MultiDex للسماح للتطبيق بتجاوز حد 65 ألف دالة.
        multiDexEnabled = true
    }

    //--------------------------------------------------------------------------

    // تعريف أنواع البناء المختلفة (Build Types).
    buildTypes {
        // إعدادات النسخة النهائية (Release) التي يتم رفعها للمتجر.
        release {
            // تفعيل تصغير حجم الكود (Minification) لإزالة الكود غير المستخدم.
            isMinifyEnabled = true
            // تفعيل تقليص حجم الموارد لإزالة الموارد غير المستخدمة.
            isShrinkResources = true
            // تحديد ملفات قواعد ProGuard لتصغير الكود وحمايته.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // تعطيل إمكانية تصحيح الأخطاء (Debugging) في النسخة النهائية.
            isDebuggable = false
            // تحديد إعدادات التوقيع للنسخة النهائية (يجب تغييره إلى إعدادات التوقيع الخاصة بك).
            signingConfig = signingConfigs.getByName("debug") // Change this to your release signing config
        }
        // إعدادات نسخة تصحيح الأخطاء (Debug) المستخدمة أثناء التطوير.
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            // إضافة لاحقة لمعرف التطبيق لتمييز نسخة الـ Debug.
           //applicationIdSuffix = ".debug"
            // إضافة لاحقة لاسم الإصدار لتمييز نسخة الـ Debug.
            versionNameSuffix = "-debug"
        }
    }

    //--------------------------------------------------------------------------

    // تفعيل ميزات بناء إضافية.
    buildFeatures {
        // تفعيل إنشاء كلاس BuildConfig تلقائيًا.
        buildConfig = true
    }

    //--------------------------------------------------------------------------

    // إعدادات تجميع حزمة التطبيق (APK).
    packaging {
        // استثناء ملفات الترخيص المتضاربة التي قد تأتي من مكتبات مختلفة.
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/LICENSE*"
        }
    }

    //--------------------------------------------------------------------------

    // إعدادات أداة تحليل الكود (Lint).
    lint {
        // تفعيل التحقق من الكود عند بناء النسخة النهائية.
        checkReleaseBuilds = true
        // إيقاف عملية البناء في حال وجود أخطاء من Lint.
        abortOnError = true
    }

    //--------------------------------------------------------------------------

    // سكريبت مخصص لإعادة تسمية ملفات APK الناتجة.
    android.applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                // إعادة تسمية الملف إلى "app-debug.apk" أو "app-release.apk".
                output.outputFileName = "app-${variant.buildType.name}.apk"
            }
    }
}

//------------------------------------------------------------------------------

// --- إعدادات خاصة بـ Flutter ---
flutter {
    // تحديد المسار النسبي لمشروع Flutter.
    source = "../.."
}

//------------------------------------------------------------------------------

// --- الاعتماديات (Dependencies) الخاصة بالجزء الأصلي (Native) من أندرويد ---
dependencies {
    // المكتبة القياسية للغة Kotlin.
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.22")
    // مكتبة لدعم MultiDex.
    implementation("androidx.multidex:multidex:2.0.1")
    
    // مكتبات Google Play Core.
    implementation("com.google.android.play:core:1.10.3")
    implementation("com.google.android.play:core-ktx:1.8.1")
}
