import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart'; // <-- 1. استيراد الحزمة الجديدة

/// يمثل هذا الكلاس نموذج البيانات لحساب المستخدم الذي سيتم تخزينه في Firestore.
/// يرث من Equatable لضمان المقارنة الصحيحة بين الكائنات.
class UserAccountModel extends Equatable {
  // <-- 2. جعله يرث من Equatable
  final String uid; // معرف المستخدم الفريد من Firebase Authentication
  final String email;
  final String fullName;
  final String role; // يمكن أن يكون 'admin' أو 'technician' أو 'supervisor'
  final DateTime createdAt;
  final bool isActive;
  final int points;
  final int tasksCompleted;
  final int devicesRegistered;

  const UserAccountModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.role =
        'technician', // القيمة الافتراضية لأي مستخدم جديد هي 'technician'
    required this.createdAt,
    this.isActive = true, // القيمة الافتراضية عند إنشاء مستخدم جديد
    this.points = 0,
    this.tasksCompleted = 0,
    this.devicesRegistered = 0,
  });

  /// *** [مهم] *** تحديد الخصائص التي سيتم استخدامها للمقارنة بين كائنين.
  /// هنا، نعتبر أن حسابين متساويين إذا كان لهما نفس الـ uid.
  @override
  List<Object?> get props => [uid];

  /// دالة لتحويل بيانات المستخدم إلى صيغة Map لتخزينها في Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
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
      isActive: map['isActive'] ?? true,
      points: (map['points'] ?? 0).toInt(),
      tasksCompleted: (map['tasksCompleted'] ?? 0).toInt(),
      devicesRegistered: (map['devicesRegistered'] ?? 0).toInt(),
    );
  }
}
