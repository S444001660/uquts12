import 'package:cloud_firestore/cloud_firestore.dart';

class UserTaskModel {
  final String id;
  final String taskId;
  final String userId;
  final bool isCompleted;
  final int progress;
  final Timestamp assignedAt;
  final Timestamp? completedAt; // يمكن أن يكون فارغاً

  UserTaskModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.isCompleted,
    required this.progress,
    required this.assignedAt,
    this.completedAt,
  });

  /// Factory constructor لإنشاء كائن من بيانات Firestore
  factory UserTaskModel.fromMap(Map<String, dynamic> map) {
    return UserTaskModel(
      id: map['id'] ?? '',
      taskId: map['taskId'] ?? '',
      userId: map['userId'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      progress: map['progress'] ?? 0,
      assignedAt: map['assignedAt'] ?? Timestamp.now(),
      completedAt: map['completedAt'], // قد يكون null
    );
  }

  /// دالة لتحويل الكائن إلى Map لإرساله إلى Firestore (إذا احتجت لذلك)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'isCompleted': isCompleted,
      'progress': progress,
      'assignedAt': assignedAt,
      'completedAt': completedAt,
    };
  }
}
