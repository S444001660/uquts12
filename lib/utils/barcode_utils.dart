// استيراد المكتبات والملفات الضرورية
import 'package:mobile_scanner/mobile_scanner.dart'; // لاستخدام كائن الباركود (Barcode).

//------------------------------------------------------------------------------

/// كلاس خدمي (Utility Class) يحتوي على دوال مساعدة ثابتة (static) للتعامل مع الباركود.
/// يمكن استدعاء هذه الدوال مباشرة من أي مكان في التطبيق دون الحاجة لإنشاء كائن من الكلاس.
class BarcodeUtils {
  /// دالة لتحليل كائن الباركود المستلم من الماسح واستخراج معلومات ذات صلة.
  static Map<String, String?> parseUniversityBarcode(Barcode barcode) {
    // الحصول على القيمة النصية الخام للباركود، مع إرجاع سلسلة فارغة إذا كانت القيمة null.
    final rawValue = barcode.rawValue ?? '';

    // إرجاع خريطة (Map) تحتوي على البيانات المنظمة.
    return {
      'barcode': rawValue, // الباركود الأصلي.
      'assetSource': 'جامعة أم القرى', // مصدر افتراضي للأصل.
      'assetCategory': _determineAssetCategory(rawValue), // تحديد فئة الأصل.
      'assetCode':
          rawValue, // استخدام الباركود الخام كرمز للأصل في هذا التطبيق المبسط.
    };
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة خاصة (_ private) لتحديد فئة الأصل بناءً على محتوى الباركود.
  /// (ملاحظة: هذا تطبيق مبسط ويمكن تطويره ليشمل منطقًا أكثر تعقيدًا).
  static String _determineAssetCategory(String barcodeValue) {
    // مثال: إذا كان الباركود يحتوي على كلمة "computer"، يتم تصنيفه كـ "معدات حاسب".
    if (barcodeValue.contains('computer')) return 'معدات حاسب';
    if (barcodeValue.contains('lab')) return 'معدات معملية';
    // إذا لم يتطابق أي شرط، يتم إرجاع فئة افتراضية.
    return 'معدات عامة';
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من صحة سلسلة الباركود.
  static bool isValidBarcode(String? barcodeValue) {
    // إذا كانت قيمة الباركود فارغة (null) أو تحتوي فقط على مسافات، فهي غير صالحة.
    if (barcodeValue == null || barcodeValue.trim().isEmpty) {
      return false;
    }

    // يمكن إضافة منطق تحقق أكثر تحديدًا هنا حسب الحاجة (مثل التحقق من تنسيق معين).
    // هنا، نكتفي بالتحقق من أن طول الباركود لا يقل عن 5 أحرف.
    return barcodeValue.trim().length >= 5;
  }

  //------------------------------------------------------------------------------

  /// دالة لإنشاء رمز أصل موحد (Standardized Asset Code).
  static String generateAssetCode(String baseCode) {
    // مثال: إنشاء رمز موحد عن طريق إضافة بادئة "UQU-" وسنة الإدخال الحالية.
    return 'UQU-${DateTime.now().year}-${baseCode.trim()}';
  }
}
