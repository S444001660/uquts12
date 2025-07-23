import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'add_device_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  final String? userTaskId;
  final bool isAdminView;

  const TaskDetailsScreen(
      {super.key,
      required this.taskId,
      this.userTaskId,
      this.isAdminView = false});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  Map<String, dynamic>? taskData;
  Map<String, dynamic>? userTaskData;
  File? proofImage;
  final TextEditingController noteController = TextEditingController();
  bool isLoading = true;
  bool showProofImageError = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final taskSnap = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .get();

    Map<String, dynamic>? userTask;

    if (!widget.isAdminView && widget.userTaskId != null) {
      final userTaskSnap = await FirebaseFirestore.instance
          .collection('user_tasks')
          .doc(widget.userTaskId)
          .get();
      userTask = userTaskSnap.data();
    }

    setState(() {
      taskData = taskSnap.data();
      userTaskData = userTask;
      isLoading = false;
    });
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        proofImage = File(picked.path);
        showProofImageError = false;
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

  Future<void> completeTask() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
      showProofImageError = false;
    });

    if (proofImage == null) {
      setState(() {
        isLoading = false;
        showProofImageError = true;
      });
      return;
    }

    if (widget.userTaskId == null) return;

    final proofUrl = await uploadProofImage(widget.taskId, widget.userTaskId!);
    final note = noteController.text;

    await FirebaseFirestore.instance
        .collection('user_tasks')
        .doc(widget.userTaskId)
        .update({
      'isCompleted': true,
      'completedAt': Timestamp.now(),
      'proofImages': proofUrl != null ? [proofUrl] : [],
      'completionNote': note,
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'points': FieldValue.increment(3),
    });

    if (mounted) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إكمال المهمة بنجاح')),
      );
      Navigator.pop(context);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (isLoading || taskData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 👈 حالة الأدمن (عرض فقط)
    if (widget.isAdminView) {
      return Scaffold(
        appBar: AppBar(
          title: Text(taskData?['typeDisplayName'] ?? 'مهمة'),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _infoTile('نوع المهمة', taskData!['typeDisplayName']),
                _infoTile('الوصف', taskData!['notes']),
                _infoTile(
                  'الحالة',
                  userTaskData?['isCompleted'] == true
                      ? 'مكتملة'
                      : 'غير مكتملة',
                ),
                _infoTile(
                  'تاريخ الإنشاء',
                  (taskData!['createdAt'] as Timestamp?)?.toDate().toString() ??
                      '---',
                ),
                if (taskData!['college'] != null)
                  _infoTile('الكلية', taskData!['college']),
                if (taskData!['targetCount'] != null)
                  _infoTile(
                      'العدد المستهدف', taskData!['targetCount'].toString()),
              ],
            ),
          ),
        ),
      );
    }

    final isCompleted = userTaskData!['isCompleted'] == true;
    final note = userTaskData!['completionNote'] ?? '';
    final proofImages = (userTaskData!['proofImages'] ?? []) as List;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المهمة')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _infoTile('نوع المهمة', taskData!['typeDisplayName']),
              _infoTile('الوصف', taskData!['notes']),
              const SizedBox(height: 16),
              if (isCompleted) ...[
                _infoTile('ملاحظات الفني', note.isEmpty ? 'لا توجد' : note),
                if (proofImages.isNotEmpty) ...[
                  const Text('صور الإثبات:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: proofImages.map<Widget>((url) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظاتك',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (proofImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      proofImage!,
                      height: 230,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: showProofImageError
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                      width: 1.5,
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: pickImage,
                    icon: Icon(Icons.camera_alt,
                        color: Theme.of(context).primaryColor),
                    label: Text(
                      proofImage != null ? 'تغيير الصورة' : 'التقاط صورة',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                  ),
                ),
                if (showProofImageError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'يرجى إرفاق صورة لإكمال المهمة',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: completeTask,
                  icon: const Icon(Icons.check),
                  label: const Text('إكمال المهمة'),
                ),
                if (taskData!['type'] == 'add_device') ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddDeviceScreen(
                            taskId: widget.taskId,
                            userTaskId: widget.userTaskId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة جهاز'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(value?.toString() ?? '---'),
        ),
        const Divider(),
      ],
    );
  }
}
