import 'package:flutter/material.dart';

//------------------------------------------------------------------------------

/// كلاس خدمي (Utility Class) شامل يحتوي على مجموعة من الدوال الثابتة (static)
/// المستخدمة للتحقق من صحة مختلف حقول النماذج (Forms) والبيانات.
///
/// تجميع منطق التحقق في مكان واحد يجعله قابلاً لإعادة الاستخدام ويضمن
/// الاتساق في رسائل الأخطاء وتجربة المستخدم في جميع أنحاء التطبيق.
class ValidationUtils {
  /// دالة للتحقق من أن الحقل ليس فارغًا.
  /// تستخدم للحقول التي يجب أن تحتوي على قيمة.
  static String? validateRequired(String? value, String errorMessage) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage;
    }
    return null;
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من حقول الأسماء (مثل اسم الجهاز أو المعمل).
  /// تدعم رسالة خطأ مخصصة عبر `fieldName` الاختياري.
  static String? validateName(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null
          ? 'الرجاء إدخال $fieldName'
          : 'الرجاء إدخال الاسم';
    }
    return null; // القيمة صالحة
  }

  //------------------------------------------------------------------------------

  /// دالة بسيطة للتحقق من أن حقل الرقم التسلسلي ليس فارغًا.
  /// يجب أن يكون أحرفًا وأرقامًا إنجليزية فقط، وطوله 10 أحرف/أرقام بالضبط.
  static String? validateSerialNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الرقم التسلسلي مطلوب';
    }
    // التحقق من أن الرقم التسلسلي يتكون من 10 أحرف/أرقام إنجليزية فقط
    final serialNumberRegex = RegExp(r'^[a-zA-Z0-9]{10}$');
    if (!serialNumberRegex.hasMatch(value.trim())) {
      return 'الرقم التسلسلي يجب أن يتكون من 10 أحرف/أرقام إنجليزية فقط';
    }
    return null;
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من صحة البريد الإلكتروني باستخدام التعابير النمطية (RegExp).
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الرجاء إدخال البريد الإلكتروني';
    }
    // تعبير نمطي بسيط للتحقق من وجود @ و . في البريد الإلكتروني.
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'البريد الإلكتروني غير صالح';
    }
    return null;
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من صحة رقم الهاتف باستخدام التعابير النمطية (RegExp).
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الرجاء إدخال رقم الهاتف';
    }
    // تعبير نمطي للتحقق من أن القيمة تتكون من 10 إلى 14 رقمًا، مع احتمالية وجود علامة +.
    final phoneRegex = RegExp(r'^[+]?[0-9]{10,14}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'رقم الهاتف غير صالح';
    }
    return null;
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من صحة رابط URL اختياري.
  /// إذا كان الحقل فارغًا، تعتبر القيمة صالحة. إذا لم يكن فارغًا، يتم التحقق من التنسيق.
  static String? validateOptionalUrl(String? value) {
    // إذا كانت القيمة فارغة، فهي صالحة لأن الحقل اختياري.
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    // تعبير نمطي معقد للتحقق من تنسيق الروابط (URL).
    final urlRegex = RegExp(
        r'^(https?:\/\/)?' // بروتوكول اختياري (http/https)
        r'(([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}' // اسم النطاق
        r'(\.[a-z]{2,})?' // نطاق المستوى الأعلى الاختياري
        r'(:\d+)?' // منفذ اختياري
        r'(\/[-a-z\d%_.~+]*)*' // مسار اختياري
        r'(\?[;&a-z\d%_.~+=-]*)?' // استعلام اختياري
        r'(#[-a-z\d_]*)?$', // علامة مرجعية اختيارية
        caseSensitive: false);

    if (!urlRegex.hasMatch(value.trim())) {
      return 'رابط غير صالح';
    }

    return null;
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة لتفعيل التحقق على الفورم بالكامل.
  /// تحتوي على رد نداء (callback) اختياري `onValidationFailed` لتنفيذ إجراء معين
  /// (مثل إظهار SnackBar) عند فشل التحقق.
  static bool validateForm(GlobalKey<FormState> formKey,
      {VoidCallback? onValidationFailed}) {
    // استدعاء دالة validate() على الفورم والحصول على النتيجة.
    final isValid = formKey.currentState?.validate() ?? false;

    // إذا كان الفورم غير صالح وتم تمرير دالة onValidationFailed، يتم استدعاؤها.
    if (!isValid && onValidationFailed != null) {
      onValidationFailed();
    }

    return isValid;
  }

  //------------------------------------------------------------------------------

  /// دالة عامة (generic) للتحقق من أن المستخدم قد اختار قيمة من قائمة منسدلة.
  /// تتأكد فقط من أن القيمة ليست `null`.
  static String? validateDropdown<T>(T? value, {String? errorMessage}) {
    if (value == null) {
      return errorMessage ?? 'الرجاء اختيار قيمة';
    }
    return null;
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من الحقول الرقمية.
  /// تتأكد من أن القيمة رقمية، وتدعم التحقق من الحدود الدنيا (`minValue`) والقصوى (`maxValue`).
  static String? validateNumeric(String? value,
      {int? minValue, int? maxValue}) {
    if (value == null || value.trim().isEmpty) {
      return 'الرجاء إدخال قيمة رقمية';
    }

    // محاولة تحويل النص إلى رقم.
    final numValue = num.tryParse(value.trim());

    if (numValue == null) {
      return 'القيمة يجب أن تكون رقمية';
    }

    if (minValue != null && numValue < minValue) {
      return 'القيمة يجب أن تكون أكبر من أو تساوي $minValue';
    }

    if (maxValue != null && numValue > maxValue) {
      return 'القيمة يجب أن تكون أقل من أو تساوي $maxValue';
    }

    return null;
  }
}
