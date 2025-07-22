// استيراد المكتبات والملفات الضرورية
import 'dart:io'; // للتعامل مع كائن الملف (File).
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // مكتبة لاختيار الصور من الكاميرا أو المعرض.
import 'package:path_provider/path_provider.dart'; // للحصول على مسارات تخزين الملفات في التطبيق.
import 'package:path/path.dart'
    as path; // لتسهيل التعامل مع مسارات الملفات (مثل الحصول على اسم الملف).
import 'package:flutter_image_compress/flutter_image_compress.dart'; // مكتبة لضغط الصور.

//------------------------------------------------------------------------------

/// كلاس خدمي (Utility Class) يحتوي على دوال مساعدة ثابتة (static)
/// لتسهيل العمليات المتعلقة بالصور، مثل الالتقاط، الحفظ، الضغط، والتحقق.
class ImageUtils {
  /// دالة غير متزامنة لاختيار صورة من الكاميرا أو المعرض مع خيارات متعددة.
  ///
  /// [context] هو سياق الويدجت (غير مستخدم حاليًا ولكن قد يكون مفيدًا مستقبلاً).
  /// [source] يحدد مصدر الصورة (كاميرا أو معرض).
  /// [maxWidth], [maxHeight], [imageQuality] هي خيارات لتغيير حجم وجودة الصورة عند الالتقاط.
  /// [maxSizeInBytes] هو الحد الأقصى لحجم الملف بالبايت للتحقق من صحة الصورة.
  static Future<File?> pickImage({
    required BuildContext context,
    ImageSource source = ImageSource.camera,
    bool allowCropping =
        false, // هذا الخيار غير مستخدم حاليًا ولكن يمكن إضافته لاحقًا.
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? maxSizeInBytes,
  }) async {
    final picker = ImagePicker();
    // استدعاء دالة التقاط الصورة من المكتبة.
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    // إذا ألغى المستخدم عملية الاختيار، يتم إرجاع null.
    if (pickedFile == null) return null;

    File image = File(pickedFile.path);

    // التحقق من حجم الصورة إذا تم تحديد حد أقصى.
    if (maxSizeInBytes != null) {
      final fileSize = await image.length();
      if (fileSize > maxSizeInBytes) {
        // إلقاء استثناء (Exception) برسالة واضحة للمستخدم.
        throw Exception(
            'الصورة كبيرة جدًا. الحد الأقصى المسموح به هو ${maxSizeInBytes ~/ (1024 * 1024)} ميجابايت');
      }
    }

    // خطوة اختيارية: حفظ الصورة في مجلد المستندات الخاص بالتطبيق لضمان عدم حذفها.
    image = await _saveImagePermanently(image);

    return image;
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة خاصة (_ private) لحفظ الصورة بشكل دائم في مجلد المستندات الخاص بالتطبيق.
  /// هذا يضمن بقاء الصورة حتى لو تم حذفها من ذاكرة التخزين المؤقتة.
  static Future<File> _saveImagePermanently(File image) async {
    // الحصول على مسار مجلد المستندات.
    final directory = await getApplicationDocumentsDirectory();
    // استخراج اسم الملف الأصلي من المسار.
    final fileName = path.basename(image.path);
    // نسخ الملف إلى المسار الجديد.
    final newImage = await image.copy('${directory.path}/$fileName');
    return newImage;
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لضغط ملف صورة.
  ///
  /// [file] هو ملف الصورة الأصلي.
  /// [quality] هي جودة الصورة بعد الضغط (من 0 إلى 100).
  static Future<File?> compressImage(File file, {int quality = 85}) async {
    try {
      // إنشاء اسم ملف فريد للصورة المضغوطة.
      final directory = await getApplicationDocumentsDirectory();
      final fileName = generateUniqueFileName();
      final compressedFilePath = '${directory.path}/$fileName';

      // استدعاء دالة الضغط من المكتبة.
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        compressedFilePath,
        quality: quality,
        minWidth: 1080, // تغيير حجم الصورة إلى عرض معقول.
        minHeight: 720, // تغيير حجم الصورة إلى ارتفاع معقول.
      );

      // تحويل النتيجة (XFile) إلى كائن File وإرجاعه.
      return result != null ? File(result.path) : null;
    } catch (e) {
      // تسجيل الخطأ أو التعامل معه حسب الحاجة.
      debugPrint('Image compression error: $e');
      return null; // إرجاع null في حالة فشل الضغط.
    }
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من صحة ملف الصورة.
  ///
  /// [image] هو ملف الصورة للتحقق منه.
  /// [maxSizeInMB] هو الحد الأقصى الاختياري لحجم الملف بالميجابايت.
  static bool isValidImage(File? image, {int? maxSizeInMB}) {
    if (image == null) return false;

    // التحقق من وجود الملف فعليًا على الجهاز.
    if (!image.existsSync()) return false;

    // التحقق من حجم الملف إذا تم تحديد حد أقصى.
    if (maxSizeInMB != null) {
      final sizeInBytes = image.lengthSync();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      if (sizeInMB > maxSizeInMB) return false;
    }

    return true;
  }

  //------------------------------------------------------------------------------

  /// دالة لإنشاء اسم ملف فريد باستخدام الطابع الزمني الحالي (Timestamp).
  static String generateUniqueFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'image_$timestamp.jpg';
  }
}
