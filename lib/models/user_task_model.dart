import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

//------------------------------------------------------------------------------

/// نموذج يمثل المهمة الفردية المسندة لمستخدم معين، ويرث من Equatable.
class UserTaskModel extends Equatable {
  final String id;
  final String taskId;
  final String userId;
  final bool isCompleted;
  final int progress;
  final DateTime assignedAt; // <-- تم التغيير إلى DateTime
  final DateTime? completedAt; // <-- تم التغيير إلى DateTime

  const UserTaskModel({
    required this.id,
    required this.taskId,
    required this.userId,
    this.isCompleted = false,
    this.progress = 0,
    required this.assignedAt,
    this.completedAt,
  });

  @override
  List<Object?> get props => [id];

  /// دالة لتحويل الكائن إلى Map لإرساله إلى Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'isCompleted': isCompleted,
      'progress': progress,
      'assignedAt': Timestamp.fromDate(assignedAt), // التحويل عند الإرسال
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  /// Factory constructor لإنشاء كائن من بيانات Firestore.
  factory UserTaskModel.fromMap(Map<String, dynamic> map) {
    // دالة مساعدة لتحويل Timestamp إلى DateTime بأمان
    DateTime? parseTimestamp(Timestamp? timestamp) {
      return timestamp?.toDate();
    }

    return UserTaskModel(
      id: map['id'] ?? '',
      taskId: map['taskId'] ?? '',
      userId: map['userId'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      progress: map['progress'] ?? 0,
      assignedAt: parseTimestamp(map['assignedAt']) ??
          DateTime.now(), // التحويل عند الاستقبال
      completedAt: parseTimestamp(map['completedAt']),
    );
  }
}
