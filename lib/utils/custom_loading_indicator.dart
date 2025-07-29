import 'package:flutter/material.dart';

/// ويدجت مخصص لعرض مؤشر تحميل باستخدام صورة GIF.
/// هذا يضمن أن شكل التحميل موحد في كل أنحاء التطبيق.
class CustomLoadingIndicator extends StatelessWidget {
  final double size;

  const CustomLoadingIndicator({super.key, this.size = 330.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        // استخدام Image.asset لعرض الصورة المتحركة من مجلد assets
        child: Image.asset(
          'assets/images/uqu_loader.gif', // <-- تأكد من أن اسم الملف ومساره صحيحان
          // يمكنك إضافة errorBuilder للتعامل مع حالة عدم وجود الصورة
          errorBuilder: (context, error, stackTrace) {
            // في حالة عدم العثور على الصورة، اعرض مؤشر التحميل الافتراضي
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}
