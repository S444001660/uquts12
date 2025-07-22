// services/task_progress_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TaskProgressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// يتم استدعاؤها بعد إضافة جهاز جديد لتحديث المهام المتعلقة
  static Future<void> updateDeviceRegistrationProgress(String userId) async {
    try {
      final userTasksQuery = await _firestore
          .collection('user_tasks')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      for (final userTaskDoc in userTasksQuery.docs) {
        final userTask = UserTaskModel.fromMap(userTaskDoc.data());
        final taskDoc =
            await _firestore.collection('tasks').doc(userTask.taskId).get();

        if (!taskDoc.exists) continue;
        final mainTask = TaskModel.fromMap(taskDoc.data()!);

        if (mainTask.type == 'deviceRegistration') {
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
      print('Error in updateDeviceRegistrationProgress: $e');
    }
  }

  /// جلب مهام المستخدم النشطة (الدالة التي كانت مفقودة)
  static Future<List<Map<String, dynamic>>> getUserActiveTasks(
      String userId) async {
    try {
      // 1. جلب مهام المستخدم الفردية النشطة
      final userTasksQuery = await _firestore
          .collection('user_tasks')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      if (userTasksQuery.docs.isEmpty) return [];

      final userTasks = userTasksQuery.docs
          .map((doc) => UserTaskModel.fromMap(doc.data()))
          .toList();

      // 2. استخراج معرفات المهام الرئيسية لتجنب الطلبات المتكررة
      final taskIds = userTasks.map((ut) => ut.taskId).toSet().toList();
      if (taskIds.isEmpty) return [];

      // 3. جلب كل المهام الرئيسية المطلوبة في طلب واحد
      final mainTasksQuery = await _firestore
          .collection('tasks')
          .where('id', whereIn: taskIds)
          .get();

      final mainTasksMap = {
        for (var doc in mainTasksQuery.docs)
          doc.id: TaskModel.fromMap(doc.data())
      };

      // 4. دمج بيانات مهام المستخدم مع المهام الرئيسية
      List<Map<String, dynamic>> combinedTasks = [];
      for (var userTask in userTasks) {
        if (mainTasksMap.containsKey(userTask.taskId)) {
          combinedTasks.add({
            'userTask': userTask,
            'mainTask': mainTasksMap[userTask.taskId]!,
          });
        }
      }
      return combinedTasks;
    } catch (e) {
      print('Error getting user active tasks: $e');
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
      print('Error getting top employees: $e');
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
      final userTask = UserTaskModel.fromMap(doc.data());
      totalProgress += userTask.progress;
      if (userTask.isCompleted) {
        completedCount++;
      }
    }

    final allTasksCompleted = completedCount == userTasksQuery.docs.length;
    await _firestore.collection('tasks').doc(taskId).update({
      'currentCount': totalProgress,
      'isCompleted': allTasksCompleted,
      'completedAt': allTasksCompleted ? Timestamp.now() : null,
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
