import 'package:cloud_firestore/cloud_firestore.dart';

/// يمثل هذا الكلاس نموذج البيانات لحساب المستخدم الذي سيتم تخزينه في Firestore.
class UserAccountModel {
  final String uid; // معرف المستخدم الفريد من Firebase Authentication
  final String email;
  final String fullName;
  final String role; // يمكن أن يكون 'admin' أو 'technician' أو 'supervisor'
  final DateTime createdAt;
  final bool isActive; // <--- تم إضافة الحقل المفقود هنا
  final int points;
  final int tasksCompleted;
  final int devicesRegistered;

  UserAccountModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.role =
        'technician', // القيمة الافتراضية لأي مستخدم جديد هي 'technician'
    required this.createdAt,
    this.isActive = true, // <--- القيمة الافتراضية عند إنشاء مستخدم جديد
    this.points = 0,
    this.tasksCompleted = 0,
    this.devicesRegistered = 0,
  });

  /// دالة لتحويل بيانات المستخدم إلى صيغة Map لتخزينها في Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive, // <--- تضمين الحقل الجديد عند الكتابة في Firestore
      'points': points,
      'tasksCompleted': tasksCompleted,
      'devicesRegistered': devicesRegistered,
    };
  }

  /// دالة لإنشاء كائن UserAccountModel من بيانات Map قادمة من Firestore.
  factory UserAccountModel.fromMap(Map<String, dynamic> map) {
    return UserAccountModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: (map['role'] ?? 'guest').toLowerCase(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isActive:
          map['isActive'] ?? true, // <--- استخراج الحقل الجديد عند القراءة
      points: (map['points'] ?? 0).toInt(),
      tasksCompleted: (map['tasksCompleted'] ?? 0).toInt(),
      devicesRegistered: (map['devicesRegistered'] ?? 0).toInt(),
    );
  }
}
