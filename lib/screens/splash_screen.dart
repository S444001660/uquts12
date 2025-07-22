import 'package:flutter/material.dart';
import 'dart:async';
import '../auth/auth_wrapper.dart'; // تأكد من أن هذا المسار صحيح

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // الانتقال إلى الشاشة التالية بعد مدة معينة (مثلاً 4 ثوانٍ)
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // استخدام ويدجت Image.asset مباشرة لعرض الـ GIF
        // تأكد من أن اسم الملف ومساره صحيحان
        child: Image.asset(
          'assets/images/uqu_loading.gif', // <-- غير اسم الملف هنا إذا كان مختلفاً
          // يمكنك التحكم في حجم الـ GIF إذا أردت
          width: 250,
          height: 250,
          // عرض رسالة خطأ واضحة إذا لم يتم العثور على الملف
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'خطأ في تحميل الصورة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 16),
            );
          },
        ),
      ),
    );
  }
}
