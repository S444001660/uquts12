import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import '../models/task_model.dart';
import '../models/user_task_model.dart' as user_task_model;

class TaskProgressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// يتم استدعاؤها عند إكمال مهمة يدوياً (ليست تسجيل جهاز)
  static Future<void> completeManualTask({
    required String userId,
    required String taskId,
    required String userTaskId,
    String? completionNote,
    String? proofImageUrl,
  }) async {
    try {
      final userTaskRef = _firestore.collection('user_tasks').doc(userTaskId);
      final taskDocRef = _firestore.collection('tasks').doc(taskId);

      // 1. تحديث المهمة الفرعية للمستخدم
      await userTaskRef.update({
        'isCompleted': true,
        'completedAt': Timestamp.now(),
        'completionNote': completionNote,
        'proofImages': proofImageUrl != null ? [proofImageUrl] : [],
      });

      // 2. جلب المهمة الرئيسية لإضافة النقاط
      final taskDoc = await taskDocRef.get();
      if (taskDoc.exists) {
        final mainTask = TaskModel.fromMap(taskDoc.data()!);
        // 3. إضافة النقاط وزيادة عداد المهام المكتملة للمستخدم
        await _addPointsToUser(userId, _calculateTaskPoints(mainTask));
      }

      // 4. تحديث حالة المهمة الرئيسية (هل اكتملت بالكامل أم لا)
      await _updateMainTaskStatus(taskId);
    } catch (e) {
      log('Error in completeManualTask: $e');
      rethrow; // إعادة رمي الخطأ لمعالجته في واجهة المستخدم
    }
  }

  /// يتم استدعاؤها بعد إضافة جهاز جديد لتحديث تقدم المهام المتعلقة
  static Future<void> updateDeviceRegistrationProgress(String userId) async {
    try {
      final userTasksQuery = await _firestore
          .collection('user_tasks')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      for (final userTaskDoc in userTasksQuery.docs) {
        final userTask =
            user_task_model.UserTaskModel.fromMap(userTaskDoc.data());
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
      log('Error in updateDeviceRegistrationProgress: $e');
    }
  }

  // ======================= هذه هي الدالة التي تم تصحيحها بالكامل =======================
  static Future<void> _updateMainTaskStatus(String taskId) async {
    // 1. ابحث عن أي مهمة فرعية "غير مكتملة" مرتبطة بالمهمة الرئيسية.
    final incompleteTasksQuery = await _firestore
        .collection('user_tasks')
        .where('taskId', isEqualTo: taskId)
        .where('isCompleted', isEqualTo: false)
        .limit(1) // نحتاج فقط لمعرفة ما إذا كانت هناك واحدة على الأقل.
        .get();

    // 2. إذا لم يتم العثور على أي مهمة غير مكتملة، فهذا يعني أن المهمة الرئيسية قد اكتملت.
    final bool allTasksCompleted = incompleteTasksQuery.docs.isEmpty;

    // (اختياري ولكن جيد) حساب التقدم الإجمالي لمهام تسجيل الأجهزة
    int totalProgress = 0;
    final allUserTasksQuery = await _firestore
        .collection('user_tasks')
        .where('taskId', isEqualTo: taskId)
        .get();
    if (allUserTasksQuery.docs.isNotEmpty) {
      for (var doc in allUserTasksQuery.docs) {
        final data = doc.data();
        totalProgress += (data['progress'] ?? 0) as int;
      }
    }

    // 3. تحديث مستند المهمة الرئيسية بالحالة الصحيحة.
    await _firestore.collection('tasks').doc(taskId).update({
      'isCompleted': allTasksCompleted,
      'completedAt': allTasksCompleted ? Timestamp.now() : null,
      'currentCount': totalProgress,
    });
  }
  // =================================================================================

  static Future<void> _addPointsToUser(String userId, int points) async {
    await _firestore.collection('users').doc(userId).update({
      'points': FieldValue.increment(points),
      'tasksCompleted':
          FieldValue.increment(1), // <-- هنا يتم زيادة عداد المهام
    });
  }

  static int _calculateTaskPoints(TaskModel task) {
    if (task.type == 'deviceRegistration') {
      return (task.targetCount ?? 1) * 5;
    }
    return 10;
  }

  static Future<int> _getDevicesRegisteredByUser(
      String userId, DateTime since) async {
    final query = await _firestore
        .collection('devices')
        .where('createdBy', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return query.docs.length;
  }

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
}
