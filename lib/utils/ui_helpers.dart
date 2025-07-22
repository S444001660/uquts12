import 'package:flutter/material.dart';
import 'dart:io'; // لاستخدام File

//------------------------------------------------------------------------------

/// تعداد (Enum) لتحديد أنواع الـ SnackBar المختلفة (نجاح، خطأ، تحذير، معلومة)
/// لتطبيق ألوان وتنسيقات مختلفة بناءً على النوع.
enum SnackBarType { success, error, warning, info }

//------------------------------------------------------------------------------

/// كلاس خدمي (Utility Class) مركزي لتوفير دوال مساعدة للتفاعلات مع واجهة المستخدم.
///
/// يوفر أسلوبًا متسقًا وقابلًا لإعادة الاستخدام للمهام الشائعة مثل:
/// - عرض رسائل (Snackbars) بأنواع مختلفة.
/// - عرض قوائم خيارات في ورقة سفلية (Bottom Sheet).
/// - عرض مربعات حوار (Dialogs) متنوعة.
///
/// يساعد هذا الكلاس على توحيد تجربة المستخدم في جميع أنحاء التطبيق
/// ويقلل من تكرار الكود في العمليات المتعلقة بواجهة المستخدم.
class UIHelpers {
  /// دالة عامة ومحسنة لعرض الـ SnackBar.
  /// تستخدم `SnackBarType` لتحديد لون الخلفية ولون النص بشكل ديناميكي.
  static void showSnackBar({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    Color backgroundColor;
    Color textColor;
    IconData icon; // إضافة أيقونة لـ SnackBar

    // تحديد الألوان والأيقونة بناءً على نوع الـ SnackBar.
    switch (type) {
      case SnackBarType.success:
        backgroundColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case SnackBarType.error:
        backgroundColor =
            Theme.of(context).colorScheme.error; // استخدام لون الخطأ من الثيم
        textColor = Colors.white;
        icon = Icons.error_outline;
        break;
      case SnackBarType.warning:
        backgroundColor = Colors.orange;
        textColor = Colors.black;
        icon = Icons.warning_amber_outlined;
        break;
      case SnackBarType.info:
        backgroundColor = Colors.blue;
        textColor = Colors.white;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor), // عرض الأيقونة
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(color: textColor)),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating, // لجعل SnackBar يظهر كعنصر عائم
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)), // حواف دائرية
        margin: const EdgeInsets.all(10), // هامش من الحواف
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة لعرض SnackBar للخطأ (اختصار لـ showSnackBar).
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(context: context, message: message, type: SnackBarType.error);
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة لعرض SnackBar للنجاح (اختصار لـ showSnackBar).
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(
        context: context, message: message, type: SnackBarType.success);
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لعرض مربع حوار قياسي للحصول على تأكيد من المستخدم.
  ///
  /// تُرجع `Future<bool?>` يمثل اختيار المستخدم (`true` للتأكيد، `false` للإلغاء).
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    String title = 'تأكيد',
    required String content,
    String confirmText = 'نعم',
    String cancelText = 'لا',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl, // دعم اللغة العربية
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // إرجاع false عند الإلغاء
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(true), // إرجاع true عند التأكيد
              style: confirmColor != null
                  ? TextButton.styleFrom(foregroundColor: confirmColor)
                  : null,
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// دالة لعرض مربع حوار للتحميل، لا يمكن إغلاقه بالضغط على الخارج.
  static void showLoadingDialog(BuildContext context,
      {String message = 'جاري التحميل...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة بسيطة لإغلاق أي مربع حوار أو ورقة سفلية مفتوحة حاليًا.
  static void dismissDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  //------------------------------------------------------------------------------

  /// دالة مرنة لعرض مربع حوار بمحتوى وأزرار مخصصة.
  static void showCustomDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              content,
              if (actions != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// دالة لعرض صورة داخل مربع حوار تفاعلي (`InteractiveViewer`) للسماح للمستخدم بالتكبير والتحريك.
  /// تم تعديلها لتقبل إما `File` (لصورة محلية) أو `String` (لـ URL صورة من الشبكة).
  static void showImageDialog({
    required BuildContext context,
    File? imageFile,
    String? imageUrl,
    double maxScale = 5.0,
    String? title,
  }) {
    Widget imageWidget;

    if (imageFile != null) {
      // إذا تم توفير ملف صورة محلي
      imageWidget = Image.file(imageFile, fit: BoxFit.contain);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      // إذا تم توفير رابط URL للصورة
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(Icons.broken_image,
                size: 50, color: Theme.of(context).colorScheme.error),
          );
        },
      );
    } else {
      // إذا لم يتم توفير أي مصدر صالح للصورة
      imageWidget = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text('لا توجد صورة لعرضها', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () =>
                Navigator.pop(context), // إغلاق الحوار عند النقر على الصورة
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  // للسماح بالتكبير والتحريك
                  maxScale: maxScale,
                  child: imageWidget,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (title != null) // عرض العنوان إذا تم توفيره
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 5.0,
                            color: Colors.black.withAlpha((0.5 * 255).round()),
                            offset: const Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  //------------------------------------------------------------------------------

  /// دالة قوية ومتقدمة لعرض ورقة سفلية (Bottom Sheet) قابلة للسحب وتغيير الحجم.
  /// تدعم القوائم المتداخلة وشريط البحث الاختياري.
  static void showBottomSheetOptions({
    required BuildContext context,
    required String title,
    required List<BottomSheetOption> options,
    bool enableSearch = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // للسماح للورقة بأخذ ارتفاع متغير.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.5, // الارتفاع الأولي.
          minChildSize: 0.25, // أصغر ارتفاع.
          maxChildSize: 0.9, // أكبر ارتفاع.
          expand: false, // مهم لكي لا تتجاوز حدود الشاشة
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).canvasColor, // استخدام لون الخلفية من الثيم
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // عرض شريط البحث إذا تم تفعيله.
                if (enableSearch)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'البحث',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (query) {
                        // هنا يمكنك إضافة منطق الفلترة بناءً على الـ query
                      },
                    ),
                  ),
                // عرض قائمة الخيارات.
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: options
                        .map((option) => ListTile(
                              leading: option.icon,
                              title: Text(option.title),
                              // عرض سهم إذا كان الخيار يحتوي على قائمة متداخلة.
                              trailing: option.options != null
                                  ? const Icon(Icons.chevron_right)
                                  : null,
                              onTap: () {
                                if (option.options != null) {
                                  // عرض المستوى التالي من الخيارات بشكل تعاودي (recursively).
                                  showBottomSheetOptions(
                                    context: context,
                                    title: option.title,
                                    options: option.options!,
                                  );
                                } else {
                                  // إغلاق الورقة الحالية وتنفيذ الإجراء.
                                  Navigator.pop(context);
                                  option.onTap?.call();
                                }
                              },
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//------------------------------------------------------------------------------

/// كلاس بيانات بسيط لتمثيل خيار واحد في الورقة السفلية.
/// تم تحسينه لدعم القوائم المتداخلة من خلال خاصية `options` الاختيارية.
class BottomSheetOption {
  final String title;
  final Widget? icon;
  final VoidCallback? onTap;
  final List<BottomSheetOption>? options; // قائمة الخيارات المتداخلة.

  const BottomSheetOption({
    required this.title,
    this.icon,
    this.onTap,
    this.options,
  }) : // استخدام `assert` للتأكد من أن كل خيار يجب أن يحتوي إما على `onTap` أو `options`،
        // مما يمنع الأخطاء المنطقية أثناء التطوير.
        assert(onTap != null || options != null,
            'Either onTap or options must be provided');
}
