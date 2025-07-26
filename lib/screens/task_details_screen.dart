import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../utils/ui_helpers.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  final String userTaskId;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    required this.userTaskId,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  Map<String, dynamic>? taskData;
  Map<String, dynamic>? userTaskData;
  File? proofImage;
  final TextEditingController noteController = TextEditingController();
  bool isLoading = true;
  String? _error;

  // --- متغيرات جديدة لتتبع التقدم التلقائي ---
  int _realtimeProgress = 0;
  bool _isGoalMet = false;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle) - (أساسي)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method) - (أساسي)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المهمة')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          onPressed: fetchData,
                        )
                      ],
                    ),
                  ),
                )
              : _buildTaskDetailsView(),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic) - (أساسي)
  // ===========================================================================

  /// دالة لجلب بيانات المهمة الرئيسية والمهمة الفرعية للمستخدم.
  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final taskSnap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .get();
      final userTaskSnap = await FirebaseFirestore.instance
          .collection('user_tasks')
          .doc(widget.userTaskId)
          .get();

      if (mounted) {
        taskData = taskSnap.data();
        userTaskData = userTaskSnap.data();

        if (taskData != null && taskData!['type'] == 'deviceRegistration') {
          await _calculateRealtimeProgress();
        }

        setState(() {
          isLoading = false;
        });
      }
    } catch (e, s) {
      // --- تم التعديل هنا لإضافة طباعة الخطأ ---
      debugPrint('Error fetching task details: $e');
      debugPrint('Stack trace: $s');
      if (mounted) {
        setState(() {
          isLoading = false;
          _error = 'فشل في تحميل البيانات. يرجى المحاولة مرة أخرى.';
        });
      }
    }
  }

  /// دالة لإكمال المهمة وتحديث البيانات في قاعدة البيانات.
  Future<void> completeTask() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final proofUrl = await uploadProofImage(widget.taskId, widget.userTaskId);
      final note = noteController.text;

      final batch = FirebaseFirestore.instance.batch();

      final userTaskRef = FirebaseFirestore.instance
          .collection('user_tasks')
          .doc(widget.userTaskId);
      batch.update(userTaskRef, {
        'isCompleted': true,
        'completedAt': Timestamp.now(),
        'proofImages': proofUrl != null ? [proofUrl] : [],
        'completionNote': note,
        'progress': _realtimeProgress,
      });

      final taskRef =
          FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
      batch.update(taskRef, {
        'currentCount': FieldValue.increment(_realtimeProgress),
      });

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'points': FieldValue.increment(3),
        'tasksCompleted': FieldValue.increment(1),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إكمال المهمة بنجاح'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'فشل إكمال المهمة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة المساعدة (UI Helper Widgets) - (يمكن فصلها)
  // ===========================================================================

  Widget _buildTaskDetailsView() {
    if (taskData == null || userTaskData == null) {
      return const Center(child: Text('البيانات غير متوفرة.'));
    }

    final isCompleted = userTaskData!['isCompleted'] == true;

    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTaskInfoCard(),
          const SizedBox(height: 16),
          if (taskData!['type'] == 'deviceRegistration') ...[
            _buildProgressCard(),
            const SizedBox(height: 16),
          ],
          isCompleted ? _buildCompletedView() : _buildPendingView(),
        ],
      ),
    );
  }

  Widget _buildTaskInfoCard() {
    final createdAt = (taskData!['createdAt'] as Timestamp?)?.toDate();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('معلومات المهمة',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _infoTile(
                Icons.assignment, 'نوع المهمة:', taskData!['typeDisplayName']),
            _infoTile(
                Icons.school, 'الكلية:', taskData!['college'] ?? 'غير محدد'),
            _infoTile(Icons.notes, 'الوصف:',
                taskData!['notes'].isEmpty ? 'لا يوجد' : taskData!['notes']),
            if (createdAt != null)
              _infoTile(Icons.calendar_today, 'تاريخ الإسناد:',
                  DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final int target = (taskData!['targetCount'] ?? 1).toInt();
    final double progress = target > 0 ? (_realtimeProgress / target) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التقدم المحرز',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 16),
                Text('$_realtimeProgress / $target',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('تحديث التقدم'),
                onPressed: _calculateRealtimeProgress,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedView() {
    final note = userTaskData!['completionNote'] ?? 'لا توجد';
    final proofImages = (userTaskData!['proofImages'] ?? []) as List;
    final completedAt = (userTaskData!['completedAt'] as Timestamp?)?.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تم إنجاز المهمة',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            if (completedAt != null)
              _infoTile(Icons.event_available, 'تاريخ الإنجاز:',
                  DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(completedAt)),
            _infoTile(Icons.speaker_notes, 'ملاحظاتك:', note),
            if (proofImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('صور الإثبات:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: proofImages.map<Widget>((url) {
                  return GestureDetector(
                    onTap: () => UIHelpers.showImageDialog(
                        context: context, imageUrl: url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url,
                          width: 100, height: 100, fit: BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingView() {
    if (taskData!['type'] == 'deviceRegistration' && !_isGoalMet) {
      return _buildGoalNotMetView();
    }
    return _buildCompletionForm();
  }

  Widget _buildGoalNotMetView() {
    final int target = (taskData!['targetCount'] ?? 1).toInt();
    final int remaining = target - _realtimeProgress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.flag_outlined,
                size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text('الهدف لم يكتمل بعد',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'قم بتسجيل $remaining جهاز إضافي في "${taskData!['college']}" لفتح خيار إكمال المهمة.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إكمال المهمة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'أضف ملاحظاتك (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (proofImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(proofImage!,
                    height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                    proofImage == null ? 'إرفاق صورة إثبات' : 'تغيير الصورة'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: completeTask,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تأكيد إكمال المهمة'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 6. الدوال المساعدة (Helper Functions) - (يمكن فصلها)
  // ===========================================================================

  Future<void> _calculateRealtimeProgress() async {
    if (taskData == null || userTaskData == null) return;

    final targetCollege = taskData!['college'];
    final assignedAt = (userTaskData!['assignedAt'] as Timestamp);
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final devicesSnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('createdBy', isEqualTo: userId)
        .where('college', isEqualTo: targetCollege)
        .where('createdAt', isGreaterThan: assignedAt)
        .get();

    final progress = devicesSnapshot.docs.length;
    final target = (taskData!['targetCount'] ?? 1).toInt();

    if (mounted) {
      setState(() {
        _realtimeProgress = progress;
        _isGoalMet = progress >= target;
      });
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 50, maxWidth: 1080);
    if (picked != null) {
      setState(() {
        proofImage = File(picked.path);
      });
    }
  }

  Future<String?> uploadProofImage(String taskId, String userTaskId) async {
    if (proofImage == null) return null;
    final fileName = '$userTaskId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('task_proofs')
        .child(taskId)
        .child(fileName);
    await ref.putFile(proofImage!);
    return await ref.getDownloadURL();
  }

  Widget _infoTile(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value?.toString() ?? '---',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
