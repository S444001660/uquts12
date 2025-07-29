import 'package:flutter/material.dart'; // لاستخدام Color و IconData (إذا أردت إضافة خصائص مرئية للدور)

/// تعداد (Enum) لتمثيل أدوار المستخدمين في النظام.
/// يوفر تعريفًا واضحًا ومقروءًا للأدوار المتاحة.
enum UserRole {
  admin, // مدير النظام
  supervisor, // مشرف
  technician, // فني
  guest, // زائر/مستخدم غير مسجل (إذا كان تطبيقك يدعم ذلك)
}

/// امتداد (Extension) على UserRole لتوفير خصائص إضافية مفيدة.
/// مثل الاسم المعروض باللغة العربية.
extension UserRoleExtension on UserRole {
  /// جلب الاسم المعروض (Display Name) للدور باللغة العربية.
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'رئيس القسم';
      case UserRole.supervisor:
        return 'مشرف';
      case UserRole.technician:
        return 'فني';
      case UserRole.guest:
        return 'زائر';
    }
  }

  /// جلب أيقونة مناسبة للدور (اختياري، يمكن استخدامها في واجهة المستخدم).
  IconData get icon {
    switch (this) {
      case UserRole.admin:
        return Icons.security;
      case UserRole.supervisor:
        return Icons.supervisor_account;
      case UserRole.technician:
        return Icons.engineering;
      case UserRole.guest:
        return Icons.person;
    }
  }

  /// جلب لون مناسب للدور (اختياري، يمكن استخدامه في واجهة المستخدم).
  Color get color {
    switch (this) {
      case UserRole.admin:
        return Colors.red.shade700;
      case UserRole.supervisor:
        return Colors.orange.shade700;
      case UserRole.technician:
        return Colors.blue.shade700;
      case UserRole.guest:
        return Colors.grey.shade700;
    }
  }
}

// تم نقل userRoleFromString خارج الامتداد ليصبح دالة مستقلة
UserRole userRoleFromString(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return UserRole.admin;
    case 'supervisor':
      return UserRole.supervisor;
    case 'technician':
      return UserRole.technician;
    case 'guest':
      return UserRole.guest;
    default:
      return UserRole.guest;
  }
}
