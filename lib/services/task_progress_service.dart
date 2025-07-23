import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

// استيراد الموديلات مع إعطاء اسم مميز للثاني لتجنب التضارب
import '../models/task_model.dart';
import '../models/user_task_model.dart'
    as user_task_model; // <--- الحل الأول: إضافة اسم مميز

class TaskProgressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// يتم استدعاؤها بعد إضافة جهاز جديد لتحديث تقدم المهام المتعلقة
  static Future<void> updateDeviceRegistrationProgress(String userId) async {
    try {
      final userTasksQuery = await _firestore
          .collection('user_tasks')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      for (final userTaskDoc in userTasksQuery.docs) {
        // استخدام الاسم المميز للوصول إلى الموديل الصحيح
        final userTask =
            user_task_model.UserTaskModel.fromMap(userTaskDoc.data());
        final taskDoc =
            await _firestore.collection('tasks').doc(userTask.taskId).get();

        if (!taskDoc.exists) continue;
        final mainTask = TaskModel.fromMap(taskDoc.data()!);

        if (mainTask.type == 'deviceRegistration') {
          // --- الحل الثاني: حذف .toDate() لأن createdAt هو بالفعل DateTime ---
          final devicesCount =
              await _getDevicesRegisteredByUser(userId, mainTask.createdAt);
          final isCompleted = devicesCount >= (mainTask.targetCount ?? 1);

          await userTaskDoc.reference.update({
            'progress': devicesCount,
            'isCompleted': isCompleted,
            'completedAt': isCompleted ? Timestamp.now() : null,
          });

          if (isCompleted && userTask.completedAt == null) {
            await _addPointsToUser(userId, _calculateTaskPoints(mainTask));
          }
          await _updateMainTaskStatus(mainTask.id);
        }
      }
    } catch (e) {
      log('Error in updateDeviceRegistrationProgress: $e');
    }
  }

  /// جلب المهام التي أنشأها أدمن معين
  static Future<List<Map<String, dynamic>>> getTasksAssignedByAdmin(
      String adminId) async {
    try {
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('createdBy', isEqualTo: adminId)
          .get();

      List<Map<String, dynamic>> result = [];

      for (final taskDoc in tasksSnapshot.docs) {
        final userTasksSnapshot = await _firestore
            .collection('user_tasks')
            .where('taskId', isEqualTo: taskDoc.id)
            .get();

        for (final userTaskDoc in userTasksSnapshot.docs) {
          result.add({
            'mainTask': taskDoc.data(),
            'userTask': userTaskDoc.data(),
          });
        }
      }
      return result;
    } catch (e) {
      log('Error loading assigned tasks by admin: $e');
      return [];
    }
  }

  /// جلب المهام النشطة لمستخدم معين
  static Future<List<Map<String, dynamic>>> getUserActiveTasks(
      String userId) async {
    try {
      final userTasksSnapshot = await _firestore
          .collection('user_tasks')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      List<Map<String, dynamic>> result = [];

      for (final userTaskDoc in userTasksSnapshot.docs) {
        final userTaskData = userTaskDoc.data();
        final taskId = userTaskData['taskId'];

        final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
        if (!taskDoc.exists) continue;

        final mainTaskData = taskDoc.data();

        result.add({
          'mainTask': mainTaskData,
          'userTask': userTaskData,
        });
      }
      return result;
    } catch (e) {
      log('Error loading user active tasks: $e');
      return [];
    }
  }

  /// جلب أفضل الموظفين حسب النقاط
  static Future<List<Map<String, dynamic>>> getTopEmployees(
      {int limit = 10}) async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('role', whereIn: ['technician', 'supervisor'])
          .orderBy('points', descending: true)
          .limit(limit)
          .get();

      return usersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName'] ?? 'غير محدد',
          'employeeId': data['employeeId'] ?? '',
          'points': data['points'] ?? 0,
          'tasksCompleted': data['tasksCompleted'] ?? 0,
          'devicesRegistered': data['devicesRegistered'] ?? 0,
          'department': data['department'] ?? '',
          'role': data['role'] ?? 'technician',
        };
      }).toList();
    } catch (e) {
      log('Error getting top employees: $e');
      return [];
    }
  }

  // --- دوال مساعدة خاصة ---

  static Future<int> _getDevicesRegisteredByUser(
      String userId, DateTime since) async {
    final query = await _firestore
        .collection('devices')
        .where('createdBy', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return query.docs.length;
  }

  static Future<void> _updateMainTaskStatus(String taskId) async {
    final userTasksQuery = await _firestore
        .collection('user_tasks')
        .where('taskId', isEqualTo: taskId)
        .get();
    if (userTasksQuery.docs.isEmpty) return;

    int totalProgress = 0;
    int completedCount = 0;
    for (var doc in userTasksQuery.docs) {
      // استخدام الاسم المميز للوصول إلى الموديل الصحيح
      final userTask = user_task_model.UserTaskModel.fromMap(doc.data());
      totalProgress += userTask.progress;
      if (userTask.isCompleted) {
        completedCount++;
      }
    }

    final allAssignedTasksCompleted =
        completedCount == userTasksQuery.docs.length;
    await _firestore.collection('tasks').doc(taskId).update({
      'currentCount': totalProgress,
      'isCompleted': allAssignedTasksCompleted,
      'completedAt': allAssignedTasksCompleted ? Timestamp.now() : null,
    });
  }

  static Future<void> _addPointsToUser(String userId, int points) async {
    await _firestore.collection('users').doc(userId).update({
      'points': FieldValue.increment(points),
      'tasksCompleted': FieldValue.increment(1),
    });
  }

  static int _calculateTaskPoints(TaskModel task) {
    if (task.type == 'deviceRegistration') {
      return (task.targetCount ?? 1) * 5; // 5 نقاط لكل جهاز
    }
    return 10; // نقاط افتراضية للمهام الأخرى
  }
}
