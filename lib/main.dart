// استيراد المكتبات والملفات الضرورية
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

// استيرادات Firebase الضرورية
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// استيراد الشاشة التي سيبدأ منها التطبيق
import 'package:uquts1/auth/auth_wrapper.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

//------------------------------------------------------------------------------

// ===========================================================================
// 1. نقطة بداية التطبيق (Main Entry Point) - (أساسي)
// ===========================================================================

/// دالة main هي نقطة البداية لتشغيل التطبيق.
void main() async {
  // التأكد من تهيئة جميع الروابط اللازمة قبل تشغيل التطبيق.
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase باستخدام الخيارات الافتراضية للمنصة الحالية.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تحديد اتجاهات الشاشة المسموح بها للتطبيق (هنا، فقط الوضع العمودي).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // تشغيل التطبيق عن طريق تمرير الويدجت الجذر (Root Widget).
  runApp(const MyApp());
}

//------------------------------------------------------------------------------

// ===========================================================================
// 2. الويدجت الجذر للتطبيق (Root Widget) - (أساسي)
// ===========================================================================

/// الويدجت الجذر للتطبيق، وهو من نوع StatelessWidget لأنه لا يحتوي على حالة داخلية تتغير.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  //----------------------------------------------------------------------------

  /// دالة build هي المسؤولة عن بناء واجهة المستخدم للويدجت.
  @override
  Widget build(BuildContext context) {
    // إنشاء الثيم (Theme) الأساسي للتطبيق باستخدام نظام الألوان Material 3.
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF006666), // اللون الأساسي (Teal).
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    // بناء الويدجت الرئيسي للتطبيق (MaterialApp).
    return MaterialApp(
      title: 'نظام إدارة المعامل',
      debugShowCheckedModeBanner: false,
      

      // --- إعدادات التعريب واللغة العربية ---
      locale: const Locale('ar', 'SA'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'),
      ],
      
      navigatorObservers: [routeObserver],

      // --- تخصيص الثيم (Theme) ---
      theme: baseTheme.copyWith(
        textTheme:
            GoogleFonts.notoKufiArabicTextTheme(baseTheme.textTheme).apply(
          fontFamilyFallback: ['Roboto', 'Arial'],
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: baseTheme.colorScheme.primary,
          foregroundColor: baseTheme.colorScheme.onPrimary,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: baseTheme.colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: baseTheme.colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: baseTheme.colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: baseTheme.colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: baseTheme.colorScheme.error, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),

      // تحديد الشاشة الرئيسية التي ستظهر عند تشغيل التطبيق.
      home: const AuthWrapper(),
    );
  }
}
