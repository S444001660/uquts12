import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // لاستخدام debugPrint
import '../models/user_account_model.dart';
import '../models/user_role_model.dart';

/// كلاس خدمي لإدارة صلاحيات المستخدمين والوصول إلى بياناتهم بكفاءة.
/// يستخدم التخزين المؤقت (Caching) لتقليل عدد مرات القراءة من قاعدة البيانات.
class PermissionsService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- [تمت الإضافة] --- متغيرات للتخزين المؤقت (Caching)
  static UserAccountModel? _currentUser;
  static UserRole? _currentUserRole;

  /// --- [تم التحديث] --- دالة لمسح الذاكرة المؤقتة عند تسجيل الخروج.
  static void clearCache() {
    _currentUser = null;
    _currentUserRole = null;
    debugPrint('PermissionsService: Cache has been cleared.');
  }

  /// --- [تم التحديث] --- دالة لجلب معلومات المستخدم الحالي الكاملة (من الذاكرة المؤقتة أو Firestore).
  static Future<UserAccountModel?> getCurrentUserInfo(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _currentUser != null) {
      debugPrint('PermissionsService: Returning cached user info.');
      return _currentUser;
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        _currentUser = UserAccountModel.fromMap(doc.data()!);
        debugPrint('PermissionsService: User info fetched and cached.');
        return _currentUser;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching user info: $e");
      return null;
    }
  }

  /// --- [تم التحديث] --- دالة لجلب دور (Role) المستخدم الحالي.
  static Future<UserRole> getCurrentUserRole() async {
    // إذا كان الدور موجودًا في الذاكرة المؤقتة، أرجعه مباشرة.
    if (_currentUserRole != null) {
      debugPrint('PermissionsService: Returning cached user role.');
      return _currentUserRole!;
    }

    final user =
        await getCurrentUserInfo(); // ستستخدم هذه الدالة الذاكرة المؤقتة إذا أمكن
    if (user != null) {
      // قم بتخزين الدور في الذاكرة المؤقتة.
      _currentUserRole = userRoleFromString(user.role);
      debugPrint(
          'PermissionsService: User role fetched and cached: ${_currentUserRole?.name}');
      return _currentUserRole!;
    }

    return UserRole.guest; // القيمة الافتراضية في حالة عدم وجود مستخدم
  }

  /// دالة للتحقق مما إذا كان المستخدم الحالي يمتلك صلاحية معينة.
  static Future<bool> hasPermission(String permission) async {
    final role = await getCurrentUserRole();

    switch (role) {
      case UserRole.admin:
        return _adminPermissions.contains(permission);
      case UserRole.supervisor:
        return _supervisorPermissions.contains(permission);
      case UserRole.technician:
        return _technicianPermissions.contains(permission);
      case UserRole.guest:
        return _guestPermissions.contains(permission);
    }
  }

  // --- قوائم الصلاحيات لكل دور ---

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

  static const List<String> _technicianPermissions = [
    'add_device',
    'edit_device',
    'add_lab',
    'edit_lab',
    'view_my_tasks',
  ];

  static const List<String> _guestPermissions = [];
}
