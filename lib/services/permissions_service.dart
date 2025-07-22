// services/permissions_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // لاستخدام debugPrint
import '../models/user_account_model.dart'; // استيراد نموذج المستخدم
import '../models/user_role_model.dart'; // <--- استيراد الملف الجديد

// تم نقل تعريف UserRole إلى user_role_model.dart
// enum UserRole { admin, supervisor, technician }

class PermissionsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// جلب معلومات المستخدم الحالي مع دورهم من Firestore.
  static Future<UserAccountModel?> getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('PermissionsService: No current user logged in.');
      return null;
    }

    debugPrint('PermissionsService: Current user UID: ${user.uid}');

    try {
      debugPrint(
          'PermissionsService: Attempting to fetch user document from Firestore: users/${user.uid}');
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('PermissionsService: User document found. Data: $data');
        // تأكد أن البيانات الأساسية موجودة في المستند
        if (data['uid'] == null ||
            data['email'] == null ||
            data['fullName'] == null ||
            data['role'] == null) {
          debugPrint(
              'PermissionsService: User document found but missing essential fields.');
          return null; // ارجع null إذا كانت الحقول الأساسية مفقودة
        }
        return UserAccountModel.fromMap(data);
      } else {
        debugPrint(
            'PermissionsService: User document NOT found for UID: ${user.uid}');
        return null;
      }
    } catch (e) {
      debugPrint(
          'PermissionsService: Error fetching user info from Firestore: $e');
      return null;
    }
  }

  /// جلب الدور الحالي للمستخدم
  static Future<UserRole?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // الأدمن الرئيسي له صلاحيات كاملة دائماً
    if (user.email == 'admin@uqu.edu.sa') {
      return UserRole.admin;
    }

    final userInfo = await getCurrentUserInfo(); // جلب أحدث معلومات المستخدم
    final roleString =
        userInfo?.role; // استخدام حقل الدور من نموذج UserAccountModel

    // تحويل السلسلة النصية للدور إلى قيمة من تعداد UserRole
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'technician':
        return UserRole.technician;
      default:
        return UserRole
            .guest; // دور افتراضي للمستخدمين غير المعروفين أو بدون دور
    }
  }

  /// التحقق من صلاحية معينة للدور الحالي
  static Future<bool> hasPermission(String permission) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    switch (role) {
      case UserRole.admin:
        return _adminPermissions.contains(permission);
      case UserRole.supervisor:
        return _supervisorPermissions.contains(permission);
      case UserRole.technician:
        return _technicianPermissions.contains(permission);
      case UserRole.guest: // الضيوف ليس لديهم أي صلاحيات خاصة
        return _guestPermissions.contains(permission);
    }
  }

  // --- قوائم الصلاحيات لكل دور ---

  // الأدمن: كل الصلاحيات
  static const List<String> _adminPermissions = [
    'delete_lab',
    'manage_users',
    'view_reports',
    'assign_tasks',
    'add_device',
    'edit_device',
    'delete_device',
    'add_lab',
    'edit_lab',
  ];

  // المشرف (مساعد الأدمن): نفس صلاحيات الأدمن
  static const List<String> _supervisorPermissions = [
    'delete_lab',
    'manage_users',
    'view_reports',
    'assign_tasks',
    'add_device',
    'edit_device',
    'delete_device',
    'add_lab',
    'edit_lab',
  ];

  // الفني: صلاحيات محدودة
  static const List<String> _technicianPermissions = [
    'add_device', 'edit_device', 'add_lab',
    'edit_lab', // يمكنه التعديل ولكن ليس الحذف
    'view_my_tasks',
  ];

  // الضيوف: لا توجد صلاحيات خاصة (يمكن إضافة 'view_public_data' مثلاً)
  static const List<String> _guestPermissions = [];

  /// دالة لمسح الذاكرة المؤقتة (لم تعد ذات أهمية كبيرة هنا بسبب StreamBuilder في AuthWrapper)
  static void clearCache() {
    debugPrint(
        'PermissionsService: clearCache called (no internal cache to clear).');
  }
}
