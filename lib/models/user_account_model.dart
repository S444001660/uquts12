import 'package:cloud_firestore/cloud_firestore.dart';

/// يمثل هذا الكلاس نموذج البيانات لحساب المستخدم الذي سيتم تخزينه في Firestore.
class UserAccountModel {
  final String uid; // معرف المستخدم الفريد من Firebase Authentication
  final String email;
  final String fullName;
  final String role; // يمكن أن يكون 'admin' أو 'user'
  final DateTime createdAt;
  final int points; // <--- حقل جديد: نقاط المستخدم
  final int tasksCompleted; // <--- حقل جديد: عدد المهام المكتملة
  final int devicesRegistered; // <--- حقل جديد: عدد الأجهزة المسجلة

  UserAccountModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.role = 'user', // القيمة الافتراضية لأي مستخدم جديد هي 'user'
    required this.createdAt,
    this.points = 0, // <--- قيمة افتراضية
    this.tasksCompleted = 0, // <--- قيمة افتراضية
    this.devicesRegistered = 0, // <--- قيمة افتراضية
  });

  /// دالة لتحويل بيانات المستخدم إلى صيغة Map لتخزينها في Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'points': points, // <--- تضمين الحقل الجديد
      'tasksCompleted': tasksCompleted, // <--- تضمين الحقل الجديد
      'devicesRegistered': devicesRegistered, // <--- تضمين الحقل الجديد
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
      points: (map['points'] ?? 0).toInt(), // <--- استخراج الحقل الجديد
      tasksCompleted:
          (map['tasksCompleted'] ?? 0).toInt(), // <--- استخراج الحقل الجديد
      devicesRegistered:
          (map['devicesRegistered'] ?? 0).toInt(), // <--- استخراج الحقل الجديد
          
    );
  }
}
