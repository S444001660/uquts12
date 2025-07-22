// models/task_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { pending, inProgress, completed, overdue }

class TaskModel {
  final String id;
  final String type;
  final String typeDisplayName;
  final String? college;
  final List<String> assignedTo; // قائمة معرفات المستخدمين
  final String notes;
  final int? targetCount; // للمهام القابلة للقياس (مثل تسجيل 30 جهاز)
  final int currentCount; // العدد الحالي المنجز
  final bool isCompleted;
  final double completionPercentage;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? completedAt;
  final TaskStatus status;

  const TaskModel({
    required this.id,
    required this.type,
    required this.typeDisplayName,
    this.college,
    required this.assignedTo,
    required this.notes,
    this.targetCount,
    this.currentCount = 0,
    this.isCompleted = false,
    this.completionPercentage = 0.0,
    required this.createdAt,
    this.createdBy,
    this.completedAt,
    this.status = TaskStatus.pending,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'typeDisplayName': typeDisplayName,
      'college': college,
      'assignedTo': assignedTo,
      'notes': notes,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'isCompleted': isCompleted,
      'completionPercentage': completionPercentage,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'status': status.name,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      typeDisplayName: map['typeDisplayName'] ?? '',
      college: map['college'],
      assignedTo: List<String>.from(map['assignedTo'] ?? []),
      notes: map['notes'] ?? '',
      targetCount: map['targetCount']?.toInt(),
      currentCount: map['currentCount']?.toInt() ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      completionPercentage: (map['completionPercentage'] ?? 0.0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'],
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TaskStatus.pending,
      ),
    );
  }

  TaskModel copyWith({
    String? id,
    String? type,
    String? typeDisplayName,
    String? college,
    List<String>? assignedTo,
    String? notes,
    int? targetCount,
    int? currentCount,
    bool? isCompleted,
    double? completionPercentage,
    DateTime? createdAt,
    String? createdBy,
    DateTime? completedAt,
    TaskStatus? status,
  }) {
    return TaskModel(
      id: id ?? this.id,
      type: type ?? this.type,
      typeDisplayName: typeDisplayName ?? this.typeDisplayName,
      college: college ?? this.college,
      assignedTo: assignedTo ?? this.assignedTo,
      notes: notes ?? this.notes,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      isCompleted: isCompleted ?? this.isCompleted,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
    );
  }

  // حساب النسبة المئوية للإنجاز
  double calculateProgress() {
    if (targetCount == null || targetCount! <= 0) {
      return isCompleted ? 100.0 : 0.0;
    }
    return (currentCount / targetCount!) * 100;
  }

  // تحديث تقدم المهمة
  TaskModel updateProgress(int newCount) {
    final newPercentage = calculateProgress();
    final completed = targetCount != null && newCount >= targetCount!;

    return copyWith(
      currentCount: newCount,
      completionPercentage: newPercentage,
      isCompleted: completed,
      completedAt:
          completed && completedAt == null ? DateTime.now() : completedAt,
      status: completed ? TaskStatus.completed : TaskStatus.inProgress,
    );
  }
}

// نموذج مهام المستخدم الفردية
class UserTaskModel {
  final String id;
  final String taskId;
  final String userId;
  final bool isCompleted;
  final int progress;
  final DateTime assignedAt;
  final DateTime? completedAt;

  const UserTaskModel({
    required this.id,
    required this.taskId,
    required this.userId,
    this.isCompleted = false,
    this.progress = 0,
    required this.assignedAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'isCompleted': isCompleted,
      'progress': progress,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory UserTaskModel.fromMap(Map<String, dynamic> map) {
    return UserTaskModel(
      id: map['id'] ?? '',
      taskId: map['taskId'] ?? '',
      userId: map['userId'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      progress: map['progress']?.toInt() ?? 0,
      assignedAt: (map['assignedAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
